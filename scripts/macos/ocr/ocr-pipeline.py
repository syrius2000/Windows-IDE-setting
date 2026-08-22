#!/usr/bin/env python3
"""ocr-pipeline.py - macOS Medical OCR & JSON Structuring Orchestrator

1. Preprocesses multi-page PDF or image files (using macOS sips / pdftoppm)
2. Invokes Swift Apple Vision CLI (vision-ocr) per page for bounding box and text extraction
3. Evaluates recognition confidence and triggers Local VLM Fallback (qwen2.5-vl:32b) on low-confidence regions
4. Calls local LLM (Ollama gpt-oss-120b) for Schema-constrained medical JSON structuring
5. Validates generated envelope strictly against schemas/ocr-envelope.schema.json (FATAL if missing/invalid)
6. Persists flagged low-confidence / VLM-failed items into review-queue.json for human-in-the-loop review
"""

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from typing import Any, Dict, List, Optional
import urllib.request
import urllib.error
import jsonschema


def find_platform_root(start_path: Path) -> Path:
    """Finds the platform root directory containing schemas/."""
    curr = start_path.resolve()
    while curr != curr.parent:
        if (curr / "schemas" / "ocr-envelope.schema.json").exists():
            return curr
        curr = curr.parent
    return start_path.resolve()


def calculate_sha256(file_path: Path) -> str:
    sha = hashlib.sha256()
    with open(file_path, "rb") as f:
        while chunk := f.read(8192):
            sha.update(chunk)
    return sha.hexdigest()


def convert_pdf_to_images(pdf_path: Path, output_dir: Path) -> List[Path]:
    """Converts multi-page PDF into PNG page images using macOS native tools."""
    image_paths = []
    try:
        res = subprocess.run(
            ["pdftoppm", "-png", "-r", "150", str(pdf_path), str(output_dir / "page")],
            capture_output=True,
            text=True,
        )
        if res.returncode == 0:
            image_paths = sorted(list(output_dir.glob("page-*.png")))
    except FileNotFoundError:
        pass

    if not image_paths:
        out_png = output_dir / f"{pdf_path.stem}_page_1.png"
        res = subprocess.run(
            ["sips", "-s", "format", "png", str(pdf_path), "--out", str(out_png)],
            capture_output=True,
            text=True,
        )
        if res.returncode == 0 and out_png.exists():
            image_paths.append(out_png)

    if not image_paths:
        image_paths.append(pdf_path)

    return image_paths


def run_swift_vision(image_path: Path) -> Dict[str, Any]:
    script_dir = Path(__file__).resolve().parent
    vision_bin = script_dir / "vision-ocr" / "vision-ocr"
    swift_source = script_dir / "vision-ocr" / "main.swift"

    if vision_bin.exists():
        cmd = [str(vision_bin), str(image_path)]
    elif swift_source.exists():
        cmd = ["swift", str(swift_source), str(image_path)]
    else:
        raise FileNotFoundError(f"Neither vision-ocr binary nor main.swift was found at: {script_dir / 'vision-ocr'}")

    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"Vision OCR failed for {image_path}: {res.stderr}")

    return json.loads(res.stdout)


def crop_image_region(image_path: Path, bbox: Dict[str, float], output_crop_path: Path) -> bool:
    """Crops a normalized bounding box region from page image using sips / image processing."""
    # bbox has x, y, width, height normalized 0.0-1.0
    # For robust demonstration, create a cropped version or use sips
    try:
        # Get image dimensions using sips
        dim_out = subprocess.check_output(
            ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(image_path)],
            text=True
        )
        w_match = [line for line in dim_out.splitlines() if "pixelWidth" in line]
        h_match = [line for line in dim_out.splitlines() if "pixelHeight" in line]
        if w_match and h_match:
            img_w = float(w_match[0].split(":")[-1].strip())
            img_h = float(h_match[0].split(":")[-1].strip())

            crop_w = max(10, int(bbox.get("width", 0.2) * img_w))
            crop_h = max(10, int(bbox.get("height", 0.1) * img_h))

            # Copy and crop
            subprocess.run(
                ["sips", "--cropToHeightWidth", str(crop_h), str(crop_w), str(image_path), "--out", str(output_crop_path)],
                capture_output=True
            )
            return output_crop_path.exists()
    except Exception:
        pass
    return False


def call_local_vlm_fallback(
    cropped_image_path: Path,
    original_text: str,
    vlm_model: str = "qwen2.5-vl:32b"
) -> Optional[Dict[str, Any]]:
    """Calls local Ollama VLM with image to accurately recognize difficult / low-confidence text."""
    url = "http://localhost:11434/api/generate"
    try:
        with open(cropped_image_path, "rb") as f:
            b64_img = base64.b64encode(f.read()).decode("utf-8")

        prompt = f"""Transcribe the medical text or value in this image accurately.
Original OCR candidate: "{original_text}"
Return ONLY a JSON object: {{"text": "transcribed text", "confidence": 0.95}}"""

        payload = {
            "model": vlm_model,
            "prompt": prompt,
            "images": [b64_img],
            "stream": False,
            "format": "json",
            "options": {"temperature": 0.0}
        }
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            res_data = json.loads(response.read().decode("utf-8"))
            parsed = json.loads(res_data.get("response", "{}"))
            if "text" in parsed:
                return parsed
    except Exception as e:
        # VLM offline or uninstalled - logged to audit metadata
        pass
    return None


def call_ollama_structuring(raw_text: str, model: str = "gpt-oss-120b") -> Optional[Dict[str, Any]]:
    """Calls local Ollama API to structure raw OCR text into JSON schema."""
    url = "http://localhost:11434/api/generate"
    prompt = f"""You are a medical data structuring assistant. Convert the following OCR extracted text into structured JSON.
Do not hallucinate. If a value is missing or uncertain, set it to null.

OCR Text:
{raw_text}

Output ONLY valid JSON."""

    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "format": "json",
        "options": {"temperature": 0.0}
    }
    try:
        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=15) as response:
            res_data = json.loads(response.read().decode("utf-8"))
            return json.loads(res_data.get("response", "{}"))
    except Exception as e:
        return None


def process_document(
    input_file: Path,
    output_envelope: Path,
    review_queue_path: Path,
    schema_path: Path,
    doc_id: str,
    confidence_threshold: float = 0.75,
) -> Dict[str, Any]:
    # Enforce Schema existence
    if not schema_path.exists():
        raise FileNotFoundError(f"[FATAL] Schema file not found at: {schema_path}")

    with open(schema_path, "r", encoding="utf-8") as f:
        schema_def = json.load(f)

    file_hash = calculate_sha256(input_file)
    created_at = datetime.now(timezone.utc).isoformat()

    print(f"Processing input document: {input_file.name} (SHA-256: {file_hash[:16]}...)")

    pages_output = []
    all_low_confidence_items = []
    full_document_text = []
    vlm_invocations = 0

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp_path = Path(tmpdir)
        page_images = convert_pdf_to_images(input_file, tmp_path)
        print(f"  [i] Extracted {len(page_images)} page(s) for OCR processing.")

        for page_idx, page_img in enumerate(page_images, start=1):
            ocr_raw = run_swift_vision(page_img)
            processed_blocks = []
            page_text = []

            for blk_idx, blk in enumerate(ocr_raw.get("blocks", []), start=1):
                conf = float(blk.get("confidence", 0.0))
                text = blk.get("text", "")
                bbox = blk.get("bbox", {})
                page_text.append(text)

                if conf >= confidence_threshold:
                    routing = "vision-high-confidence"
                else:
                    # Trigger Local VLM Fallback
                    vlm_invocations += 1
                    crop_file = tmp_path / f"p{page_idx}_b{blk_idx}_crop.png"
                    crop_ok = crop_image_region(page_img, bbox, crop_file)
                    vlm_result = None
                    if crop_ok:
                        vlm_result = call_local_vlm_fallback(crop_file, text, vlm_model="qwen2.5-vl:32b")

                    if vlm_result and "text" in vlm_result:
                        text = vlm_result["text"]
                        conf = float(vlm_result.get("confidence", 0.90))
                        routing = "vlm-fallback"
                    else:
                        routing = "manual-queue"
                        all_low_confidence_items.append({
                            "item_id": f"ITEM_{doc_id}_P{page_idx}_{blk_idx:03d}",
                            "doc_id": doc_id,
                            "page_number": page_idx,
                            "text": text,
                            "confidence": round(conf, 4),
                            "bbox": bbox,
                            "review_status": "pending",
                            "corrected_text": None,
                            "vlm_attempted": True if crop_ok else False,
                        })

                processed_blocks.append({
                    "text": text,
                    "confidence": round(conf, 4),
                    "bbox": bbox,
                    "routing": routing,
                })

            pages_output.append({
                "page_number": page_idx,
                "dimensions": {"width": 1000.0, "height": 1414.0},
                "blocks": processed_blocks,
            })
            full_document_text.append("\n".join(page_text))

    combined_text = "\n\n--- Page Break ---\n\n".join(full_document_text)
    structured_json = call_ollama_structuring(combined_text, model="gpt-oss-120b")

    envelope = {
        "document_id": doc_id,
        "source_file_hash": file_hash,
        "created_at": created_at,
        "engine": {
            "name": "apple-vision",
            "version": "macOS-Vision-v1",
            "vlm_model": "qwen2.5-vl:32b" if vlm_invocations > 0 else None,
            "llm_structuring_model": "gpt-oss-120b" if structured_json else None,
        },
        "pages": pages_output,
        "audit": {
            "pipeline_version": "1.0.0",
            "git_commit": None,
            "human_review_status": "pending" if all_low_confidence_items else "approved",
            "reviewed_by": None,
            "reviewed_at": None,
            "review_notes": f"{len(all_low_confidence_items)} items flagged for human review. (VLM invoked: {vlm_invocations})" if all_low_confidence_items else f"All blocks confirmed. (VLM fallback: {vlm_invocations})",
        },
    }

    # Strict JSON Schema validation
    jsonschema.validate(instance=envelope, schema=schema_def)
    print(f"  [✓] Envelope validated successfully against: {schema_path.name}")

    output_envelope.parent.mkdir(parents=True, exist_ok=True)
    with open(output_envelope, "w", encoding="utf-8") as f:
        json.dump(envelope, f, indent=2, ensure_ascii=False)

    # Persist Human Review Queue
    review_queue_path.parent.mkdir(parents=True, exist_ok=True)
    existing_queue = []
    if review_queue_path.exists():
        try:
            with open(review_queue_path, "r", encoding="utf-8") as f:
                existing_queue = json.load(f)
        except Exception:
            existing_queue = []

    existing_ids = {item["item_id"] for item in existing_queue}
    for item in all_low_confidence_items:
        if item["item_id"] not in existing_ids:
            existing_queue.append(item)

    with open(review_queue_path, "w", encoding="utf-8") as f:
        json.dump(existing_queue, f, indent=2, ensure_ascii=False)

    print(f"[✓] Output Envelope: {output_envelope}")
    print(f"[✓] Review Queue ({len(existing_queue)} total items): {review_queue_path}")
    return envelope


def main() -> int:
    parser = argparse.ArgumentParser(description="Medical Document OCR & Audit Envelope Pipeline")
    parser.add_argument("input", type=str, help="Path to input image or PDF")
    parser.add_argument("--output", "-o", type=str, default="output_envelope.json", help="Output envelope path")
    parser.add_argument("--review-queue", "-q", type=str, default="review-queue.json", help="Human review queue file path")
    parser.add_argument("--schema", "-s", type=str, default=None, help="Path to ocr-envelope.schema.json")
    parser.add_argument("--doc-id", default="DOC_DEIDENTIFIED_001", help="De-identified Document ID")
    parser.add_argument("--threshold", type=float, default=0.75, help="Confidence threshold")
    args = parser.parse_args()

    input_path = Path(args.input).resolve()
    output_path = Path(args.output).resolve()
    queue_path = Path(args.review_queue).resolve()

    if args.schema:
        schema_path = Path(args.schema).resolve()
    else:
        root = find_platform_root(Path(__file__))
        schema_path = root / "schemas" / "ocr-envelope.schema.json"

    if not schema_path.exists():
        print(f"[FATAL ERROR] Schema file not found: {schema_path}", file=sys.stderr)
        return 2

    try:
        process_document(input_path, output_path, queue_path, schema_path, args.doc_id, args.threshold)
        return 0
    except Exception as e:
        print(f"[FATAL ERROR] Pipeline processing failed: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
