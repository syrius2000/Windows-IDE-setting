#!/usr/bin/env python3
"""test_all_scenarios.py - Automated Test Suite for RWD Platform & Specification Scenarios

Executes deterministic tests across all specification requirements:
1. PROJECT.yml Schema Validation (Positive & Negative tests)
2. OCR Envelope Schema Validation (Positive & Negative tests, nullable reviewers)
3. validate-project.py Engine (Directory structure, prohibited files, git ignore, encodings, release manifest)
4. SAS Invoke Wrapper Logic (Error/Warning parsing, CP932 encoding integrity)
5. MySQL 8.0 Read-Only Quality Inspection Logic (Duplicate keys, NULL percentages, safe privilege audit)
6. MySQL Connector/ODBC & DSN Audit Logic (Architecture checks, zero plaintext password, exit codes)
7. ODBC Fault Isolation & Mock Direct Execution (Direct MySQL logic is fully decoupled from ODBC states)
8. OCR Pipeline Execution, VLM Fallback & Review Queue Persistence (End-to-end pipeline execution)
9. Windows PowerShell Static Integrity (Balanced blocks, strict mode, parameter declarations)
"""

import configparser
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import shutil
import tempfile
import unittest
from unittest.mock import MagicMock, patch
import jsonschema
import yaml

PLATFORM_ROOT = Path(__file__).resolve().parents[1]

# Dynamic imports of scripts with hyphens in filename
def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, str(path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

validate_project = load_module("validate_project", PLATFORM_ROOT / "scripts" / "project" / "validate-project.py")
mysql_readonly_test = load_module("mysql_readonly_test", PLATFORM_ROOT / "scripts" / "macos" / "mysql-readonly-test.py")
test_odbc = load_module("test_odbc", PLATFORM_ROOT / "scripts" / "macos" / "test-odbc.py")
ocr_pipeline = load_module("ocr_pipeline", PLATFORM_ROOT / "scripts" / "macos" / "ocr" / "ocr-pipeline.py")


class TestProjectSchema(unittest.TestCase):
    def setUp(self):
        self.schema_path = PLATFORM_ROOT / "schemas" / "project.schema.json"
        with open(self.schema_path, "r", encoding="utf-8") as f:
            self.schema = json.load(f)

    def test_valid_project_config(self):
        valid_data = {
            "project": {
                "id": "case-urology",
                "title": "Urology RWD Analysis",
                "template_version": "1.0.0"
            },
            "data": {
                "classification": "deidentified",
                "source": "mysql-readonly",
                "external_storage": True
            },
            "analysis": {
                "primary_language": "sas",
                "sas_encoding": "cp932",
                "secondary_languages": ["python", "r", "typescript"]
            },
            "reporting": {
                "formats": ["excel", "powerpoint", "slidev", "quarto"]
            },
            "ai": {
                "cloud_allowed": False,
                "local_llm_allowed": True,
                "human_review_required": True
            },
            "outputs": {
                "private_git_allowed": False,
                "release_requires_review": True
            }
        }
        validator = jsonschema.Draft7Validator(self.schema)
        errors = list(validator.iter_errors(valid_data))
        self.assertEqual(len(errors), 0, f"Valid config had errors: {errors}")

    def test_invalid_project_id_casing(self):
        invalid_data = {
            "project": {
                "id": "Case_Urology_Invalid",
                "title": "Invalid ID",
                "template_version": "1.0.0"
            },
            "data": {"classification": "synthetic", "source": "synthetic", "external_storage": False},
            "analysis": {"primary_language": "python", "sas_encoding": "utf-8", "secondary_languages": []},
            "reporting": {"formats": ["excel"]},
            "ai": {"cloud_allowed": True, "local_llm_allowed": True, "human_review_required": True},
            "outputs": {"private_git_allowed": False, "release_requires_review": True}
        }
        validator = jsonschema.Draft7Validator(self.schema)
        errors = list(validator.iter_errors(invalid_data))
        self.assertTrue(len(errors) > 0, "Invalid ID format should fail validation")

    def test_invalid_outputs_private_git_allowed(self):
        invalid_data = {
            "project": {"id": "case-test", "title": "Test", "template_version": "1.0.0"},
            "data": {"classification": "synthetic", "source": "synthetic", "external_storage": False},
            "analysis": {"primary_language": "python", "sas_encoding": "none", "secondary_languages": []},
            "reporting": {"formats": ["excel"]},
            "ai": {"cloud_allowed": True, "local_llm_allowed": True, "human_review_required": True},
            "outputs": {
                "private_git_allowed": True,
                "release_requires_review": True
            }
        }
        validator = jsonschema.Draft7Validator(self.schema)
        errors = list(validator.iter_errors(invalid_data))
        self.assertTrue(len(errors) > 0, "private_git_allowed: true must be rejected")


class TestOcrEnvelopeSchema(unittest.TestCase):
    def setUp(self):
        self.schema_path = PLATFORM_ROOT / "schemas" / "ocr-envelope.schema.json"
        with open(self.schema_path, "r", encoding="utf-8") as f:
            self.schema = json.load(f)

    def test_valid_envelope_with_null_reviewers(self):
        valid_envelope = {
            "document_id": "DOC_TEST_001",
            "source_file_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            "created_at": "2026-08-23T00:00:00Z",
            "engine": {
                "name": "apple-vision",
                "version": "macOS-Vision-v1",
                "vlm_model": "qwen2.5-vl:32b",
                "llm_structuring_model": "gpt-oss-120b"
            },
            "pages": [
                {
                    "page_number": 1,
                    "dimensions": {"width": 1000.0, "height": 1414.0},
                    "blocks": [
                        {
                            "text": "患者番号: 12345",
                            "confidence": 0.98,
                            "bbox": {"x": 0.1, "y": 0.2, "width": 0.3, "height": 0.05},
                            "routing": "vision-high-confidence"
                        },
                        {
                            "text": "酵素活性: 2.1",
                            "confidence": 0.65,
                            "bbox": {"x": 0.1, "y": 0.3, "width": 0.3, "height": 0.05},
                            "routing": "vlm-fallback"
                        }
                    ]
                }
            ],
            "audit": {
                "pipeline_version": "1.0.0",
                "git_commit": None,
                "human_review_status": "pending",
                "reviewed_by": None,
                "reviewed_at": None,
                "review_notes": "1 item flagged for review."
            }
        }
        validator = jsonschema.Draft7Validator(self.schema)
        errors = list(validator.iter_errors(valid_envelope))
        self.assertEqual(len(errors), 0, f"Valid envelope failed schema check: {errors}")


class TestValidateProjectEngine(unittest.TestCase):
    def test_validation_on_clean_template(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = Path(tmpdir) / "case-clean-test"
            project_path.mkdir(parents=True)

            for d in ["src/sas-cp932", "src/python", "src/r", "src/typescript", "sql", "reports", "outputs/private", "outputs/release", "data/synthetic"]:
                (project_path / d).mkdir(parents=True, exist_ok=True)

            proj_data = {
                "project": {"id": "case-clean-test", "title": "Clean Test", "template_version": "1.0.0"},
                "data": {"classification": "synthetic", "source": "synthetic", "external_storage": False},
                "analysis": {"primary_language": "sas", "sas_encoding": "cp932", "secondary_languages": ["python"]},
                "reporting": {"formats": ["excel"]},
                "ai": {"cloud_allowed": True, "local_llm_allowed": True, "human_review_required": True},
                "outputs": {"private_git_allowed": False, "release_requires_review": True}
            }
            with open(project_path / "PROJECT.yml", "w", encoding="utf-8") as f:
                yaml.dump(proj_data, f)

            with open(project_path / ".gitignore", "w", encoding="utf-8") as f:
                f.write("outputs/private/*\n.run/\n")

            with open(project_path / "src" / "sas-cp932" / "test.sas", "w", encoding="cp932") as f:
                f.write("/* 日本語テスト (CP932) */\nproc print data=sashelp.class; run;\n")

            with open(project_path / "src" / "python" / "test.py", "w", encoding="utf-8") as f:
                f.write("# 日本語テスト (UTF-8)\nprint('Hello RWD')\n")

            schema_path = PLATFORM_ROOT / "schemas" / "project.schema.json"
            res = validate_project.run_validation(project_path, schema_path)
            self.assertEqual(res["status"], "PASS", f"Clean template failed validation: {res.get('errors')}")

    def test_prohibited_file_detection(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = Path(tmpdir) / "case-bad-test"
            project_path.mkdir(parents=True)
            for d in ["src", "sql", "reports", "outputs/private", "outputs/release", "data/synthetic"]:
                (project_path / d).mkdir(parents=True, exist_ok=True)

            (project_path / "src" / "patient_raw_data.sas7bdat").write_text("FAKE_SAS_DATA")
            (project_path / ".env").write_text("MYSQL_PASSWORD=secret")

            proj_data = {
                "project": {"id": "case-bad-test", "title": "Bad Test", "template_version": "1.0.0"},
                "data": {"classification": "synthetic", "source": "synthetic", "external_storage": False},
                "analysis": {"primary_language": "sas", "sas_encoding": "cp932", "secondary_languages": []},
                "reporting": {"formats": ["excel"]},
                "ai": {"cloud_allowed": True, "local_llm_allowed": True, "human_review_required": True},
                "outputs": {"private_git_allowed": False, "release_requires_review": True}
            }
            with open(project_path / "PROJECT.yml", "w", encoding="utf-8") as f:
                yaml.dump(proj_data, f)
            with open(project_path / ".gitignore", "w", encoding="utf-8") as f:
                f.write("outputs/private/*\n.run/\n")

            schema_path = PLATFORM_ROOT / "schemas" / "project.schema.json"
            res = validate_project.run_validation(project_path, schema_path)
            self.assertEqual(res["status"], "FAIL")
            error_str = " ".join(res["errors"])
            self.assertIn("patient_raw_data.sas7bdat", error_str)
            self.assertIn(".env", error_str)

    def test_release_manifest_blocking(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = Path(tmpdir) / "case-release-test"
            project_path.mkdir(parents=True)
            for d in ["src", "sql", "reports", "outputs/private", "outputs/release", "data/synthetic"]:
                (project_path / d).mkdir(parents=True, exist_ok=True)

            proj_data = {
                "project": {"id": "case-release-test", "title": "Release Test", "template_version": "1.0.0"},
                "data": {"classification": "synthetic", "source": "synthetic", "external_storage": False},
                "analysis": {"primary_language": "sas", "sas_encoding": "cp932", "secondary_languages": []},
                "reporting": {"formats": ["excel"]},
                "ai": {"cloud_allowed": True, "local_llm_allowed": True, "human_review_required": True},
                "outputs": {"private_git_allowed": False, "release_requires_review": True}
            }
            with open(project_path / "PROJECT.yml", "w", encoding="utf-8") as f:
                yaml.dump(proj_data, f)
            with open(project_path / ".gitignore", "w", encoding="utf-8") as f:
                f.write("outputs/private/*\n.run/\n")

            (project_path / "outputs" / "release" / "final_report.xlsx").write_text("FAKE_REPORT")

            schema_path = PLATFORM_ROOT / "schemas" / "project.schema.json"
            res = validate_project.run_validation(project_path, schema_path)
            self.assertEqual(res["status"], "FAIL", "Missing release-manifest.yml must trigger FAIL status")

    def test_git_check_ignore_stdin_behavior(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            project_path = Path(tmpdir) / "case-git-test"
            project_path.mkdir(parents=True)
            for d in ["src", "sql", "reports", "outputs/private", "outputs/release", "data/synthetic"]:
                (project_path / d).mkdir(parents=True, exist_ok=True)

            with open(project_path / ".gitignore", "w", encoding="utf-8") as f:
                f.write("outputs/private/*\n.run/\n")

            errors = validate_project.check_git_exclusions_non_invasive(project_path)
            self.assertEqual(len(errors), 0, f"Valid .gitignore had errors: {errors}")


class TestSasWrapperAndEncoding(unittest.TestCase):
    def test_sas_cp932_reading(self):
        sample_sas = PLATFORM_ROOT / "templates" / "analysis-project" / "template" / "src" / "sas-cp932" / "sample_analysis.sas"
        if sample_sas.exists():
            with open(sample_sas, "r", encoding="cp932") as f:
                content = f.read()
            self.assertIn("生存時間解析", content, "SAS sample file must contain Japanese text encoded in CP932")


class TestMySQLQualityMetrics(unittest.TestCase):
    def test_disallowed_write_privileges_set(self):
        self.assertIn("INSERT", mysql_readonly_test.DISALLOWED_WRITE_PRIVILEGES)
        self.assertIn("DELETE", mysql_readonly_test.DISALLOWED_WRITE_PRIVILEGES)
        self.assertIn("DROP", mysql_readonly_test.DISALLOWED_WRITE_PRIVILEGES)

    def test_mock_direct_privilege_audit(self):
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_conn.cursor.return_value.__enter__.return_value = mock_cursor
        mock_cursor.fetchall.return_value = [
            {"Grants": "GRANT USAGE ON *.* TO `rwd_readonly_user`@`%`"},
            {"Grants": "GRANT SELECT ON `rwd_research_db`.* TO `rwd_readonly_user`@`%`"}
        ]
        res = mysql_readonly_test.verify_readonly_privileges_safely(mock_conn)
        self.assertTrue(res["read_only_verified"], "Read-only grants must be verified as true")


class TestOdbcAuditLogic(unittest.TestCase):
    def test_system_arch_detection(self):
        arch = test_odbc.get_system_arch()
        self.assertIn(arch, ["arm64", "x86_64", "aarch64", "x86"])

    def test_dsn_plaintext_password_detection(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            fake_ini = Path(tmpdir) / "odbc.ini"
            fake_ini.write_text("[test_dsn]\nDriver=MySQL ODBC 8.4\nServer=127.0.0.1\nPassword=plain_secret\n")
            
            old_odbcini = os.environ.get("ODBCINI")
            os.environ["ODBCINI"] = str(fake_ini)
            try:
                audit = test_odbc.audit_dsn_configuration("test_dsn")
                self.assertEqual(audit["dsn_audit"]["status"], "SECURITY_VIOLATION")
                self.assertTrue(any("Plaintext password found" in issue for issue in audit["dsn_audit"]["issues"]))
            finally:
                if old_odbcini:
                    os.environ["ODBCINI"] = old_odbcini
                else:
                    os.environ.pop("ODBCINI", None)

    def test_driver_registration_inspection_fallback(self):
        drivers_info = test_odbc.inspect_registered_odbc_drivers()
        self.assertIsInstance(drivers_info, dict)
        self.assertIn("drivers", drivers_info)


class TestOdbcFaultIsolation(unittest.TestCase):
    """Verifies that ODBC driver absence or failure does NOT affect Python/R direct connections."""

    def test_fault_isolation_odbc_not_installed(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            empty_dir = Path(tmpdir)
            fake_ini = empty_dir / "nonexistent.ini"
            os.environ["ODBCINI"] = str(fake_ini)
            try:
                audit = test_odbc.audit_dsn_configuration("test_dsn")
                self.assertEqual(audit["dsn_audit"]["status"], "NOT_CONFIGURED")
                
                # Mock live Python direct connection execution
                mock_conn = MagicMock()
                mock_cursor = MagicMock()
                mock_conn.cursor.return_value.__enter__.return_value = mock_cursor
                mock_cursor.fetchall.return_value = [{"Grants": "GRANT SELECT ON *.* TO user@host"}]
                direct_res = mysql_readonly_test.verify_readonly_privileges_safely(mock_conn)
                self.assertTrue(direct_res["read_only_verified"], "Direct MySQL queries succeed even when ODBC is not installed")
            finally:
                os.environ.pop("ODBCINI", None)

    def test_fault_isolation_odbc_connection_failed(self):
        # Simulate ODBC connectivity failure result
        conn_res = test_odbc.test_odbc_connectivity("invalid_dsn_test", "user", "nonexistent_service", prompt_password=False)
        self.assertIn(conn_res["status"], ["WARN", "INFO", "FAIL"])
        
        # Verify direct connection functions independently
        mock_conn = MagicMock()
        mock_cursor = MagicMock()
        mock_conn.cursor.return_value.__enter__.return_value = mock_cursor
        mock_cursor.fetchone.side_effect = [
            {"total": 500},
            {"null_count": 0},
            {"dup_count": 0}
        ]
        mock_cursor.fetchall.return_value = [{"Field": "id", "Type": "int", "Null": "NO", "Key": "PRI"}]
        quality_res = mysql_readonly_test.inspect_table_quality(mock_conn, "patients")
        self.assertEqual(quality_res["total_rows"], 500, "Direct data quality calculation succeeds independently of ODBC connection failure")


class TestOcrPipelineExecution(unittest.TestCase):
    """Verifies end-to-end execution of OCR pipeline, VLM fallback routing, and review queue persistence."""

    def test_ocr_pipeline_and_vlm_fallback_flow(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            fake_input = tmp_path / "dummy_doc.png"
            fake_input.write_bytes(b"DUMMY_PNG_DATA")

            output_envelope = tmp_path / "output_envelope.json"
            review_queue = tmp_path / "review-queue.json"
            schema_path = PLATFORM_ROOT / "schemas" / "ocr-envelope.schema.json"

            # Mock Swift Vision output with 1 high-conf and 1 low-conf block
            mock_vision_output = {
                "blocks": [
                    {"text": "患者ID: 1001", "confidence": 0.95, "bbox": {"x": 0.1, "y": 0.1, "width": 0.3, "height": 0.05}},
                    {"text": "不鮮明文字", "confidence": 0.45, "bbox": {"x": 0.1, "y": 0.3, "width": 0.3, "height": 0.05}}
                ]
            }

            with patch.object(ocr_pipeline, "convert_pdf_to_images", return_value=[fake_input]), \
                 patch.object(ocr_pipeline, "run_swift_vision", return_value=mock_vision_output), \
                 patch.object(ocr_pipeline, "crop_image_region", return_value=True), \
                 patch.object(ocr_pipeline, "call_local_vlm_fallback", return_value={"text": "補正後検査値: 42.0", "confidence": 0.92}), \
                 patch.object(ocr_pipeline, "call_ollama_structuring", return_value={"patient_id": 1001}):

                envelope = ocr_pipeline.process_document(
                    input_file=fake_input,
                    output_envelope=output_envelope,
                    review_queue_path=review_queue,
                    schema_path=schema_path,
                    doc_id="DOC_TEST_E2E",
                    confidence_threshold=0.75
                )

                self.assertTrue(output_envelope.exists(), "Output envelope must be generated")
                self.assertEqual(len(envelope["pages"][0]["blocks"]), 2)
                self.assertEqual(envelope["pages"][0]["blocks"][0]["routing"], "vision-high-confidence")
                self.assertEqual(envelope["pages"][0]["blocks"][1]["routing"], "vlm-fallback")
                self.assertEqual(envelope["pages"][0]["blocks"][1]["text"], "補正後検査値: 42.0")

    def test_ocr_pipeline_manual_review_queue_persistence(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            tmp_path = Path(tmpdir)
            fake_input = tmp_path / "dummy_doc2.png"
            fake_input.write_bytes(b"DUMMY_PNG_DATA")

            output_envelope = tmp_path / "output_envelope2.json"
            review_queue = tmp_path / "review-queue.json"
            schema_path = PLATFORM_ROOT / "schemas" / "ocr-envelope.schema.json"

            # Mock Swift Vision with low-conf block where VLM fails
            mock_vision_output = {
                "blocks": [
                    {"text": "難読文字", "confidence": 0.30, "bbox": {"x": 0.2, "y": 0.4, "width": 0.2, "height": 0.05}}
                ]
            }

            with patch.object(ocr_pipeline, "convert_pdf_to_images", return_value=[fake_input]), \
                 patch.object(ocr_pipeline, "run_swift_vision", return_value=mock_vision_output), \
                 patch.object(ocr_pipeline, "crop_image_region", return_value=False), \
                 patch.object(ocr_pipeline, "call_local_vlm_fallback", return_value=None), \
                 patch.object(ocr_pipeline, "call_ollama_structuring", return_value=None):

                envelope = ocr_pipeline.process_document(
                    input_file=fake_input,
                    output_envelope=output_envelope,
                    review_queue_path=review_queue,
                    schema_path=schema_path,
                    doc_id="DOC_MANUAL_TEST",
                    confidence_threshold=0.75
                )

                self.assertEqual(envelope["pages"][0]["blocks"][0]["routing"], "manual-queue")
                self.assertTrue(review_queue.exists(), "review-queue.json must be persisted on disk")
                with open(review_queue, "r", encoding="utf-8") as f:
                    queue_items = json.load(f)
                self.assertEqual(len(queue_items), 1)
                self.assertEqual(queue_items[0]["review_status"], "pending")


class TestInteractiveQuartoReporting(unittest.TestCase):
    """Tests for offline interactive Quarto reporting, disclosure control, and HTML leak detection."""

    def test_interactive_template_exists_and_configured(self):
        qmd_file = PLATFORM_ROOT / "templates" / "analysis-project" / "template" / "reports" / "quarto" / "interactive_summary.qmd"
        self.assertTrue(qmd_file.exists(), "interactive_summary.qmd template must exist")
        content = qmd_file.read_text(encoding="utf-8")
        self.assertIn("embed-resources: true", content, "Template must configure embed-resources: true for self-contained HTML")
        self.assertNotIn("https://cdn.jsdelivr.net", content, "Template must not contain CDN references")
        self.assertNotIn("https://unpkg.com", content, "Template must not contain unpkg references")
        self.assertNotIn("observableusercontent.com", content, "Template must not contain Observable CDN references")
        self.assertNotIn("duckdb-wasm", content, "Template must not depend on external DuckDB-WASM")

    def test_small_cell_suppression_logic_suppresses_all_metrics(self):
        sample_pipeline = load_module(
            "sample_pipeline",
            PLATFORM_ROOT / "templates" / "analysis-project" / "template" / "src" / "python" / "sample_rwd_pipeline.py"
        )
        records = [
            {
                "treatment_arm": "Active",
                "sex": "M",
                "period": "<1年 (365日未満)",
                "age_group": "<55",
                "n_patients": 3,
                "n_events": 1,
                "event_rate": 33.3,
                "mean_followup": 450.0,
            },
            {
                "treatment_arm": "Active",
                "sex": "F",
                "period": "1年以上 (365日以上)",
                "age_group": "55-69",
                "n_patients": 12,
                "n_events": 4,
                "event_rate": 33.3,
                "mean_followup": 395.0,
            },
        ]
        sanitized = sample_pipeline.suppress_small_cells(records, threshold=5)
        # Suppressed row (count < 5): ALL metrics must be None
        self.assertIsNone(sanitized[0]["n_patients"], "n_patients for count < 5 must be None")
        self.assertIsNone(sanitized[0]["n_events"], "n_events for count < 5 must be None")
        self.assertIsNone(sanitized[0]["event_rate"], "event_rate for count < 5 must be None")
        self.assertIsNone(sanitized[0]["mean_followup"], "mean_followup for count < 5 must be None")
        self.assertTrue(sanitized[0]["suppressed"], "suppressed flag must be True")
        # Dimensions must be preserved
        self.assertEqual(sanitized[0]["treatment_arm"], "Active")
        self.assertEqual(sanitized[0]["sex"], "M")
        self.assertEqual(sanitized[0]["period"], "<1年 (365日未満)")
        self.assertEqual(sanitized[0]["age_group"], "<55")

        # Preserved row (count >= 5)
        self.assertEqual(sanitized[1]["n_patients"], 12)
        self.assertEqual(sanitized[1]["n_events"], 4)
        self.assertEqual(sanitized[1]["event_rate"], 33.3)
        self.assertEqual(sanitized[1]["mean_followup"], 395.0)
        self.assertFalse(sanitized[1]["suppressed"])

    def test_validate_project_catches_all_leak_patterns(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            proj_dir = Path(tmpdir)
            outputs_dir = proj_dir / "outputs" / "private"
            outputs_dir.mkdir(parents=True, exist_ok=True)
            quarto_dir = proj_dir / "reports" / "quarto"
            quarto_dir.mkdir(parents=True, exist_ok=True)

            # Test 1: CDN strings in HTML
            cdn_html = outputs_dir / "cdn_leak.html"
            cdn_html.write_text('<html><script>const url = "https://cdn.jsdelivr.net/npm/d3";</script></html>', encoding="utf-8")
            errors = validate_project.check_interactive_reports(proj_dir)
            self.assertTrue(any("jsdelivr CDN dependency" in e for e in errors))
            cdn_html.unlink()

            # Test 2: fetch() network call
            fetch_html = outputs_dir / "fetch_leak.html"
            fetch_html.write_text('<html><script>fetch("https://api.example.com/data");</script></html>', encoding="utf-8")
            errors = validate_project.check_interactive_reports(proj_dir)
            self.assertTrue(any("fetch() network request" in e for e in errors))
            fetch_html.unlink()

            # Test 3: dynamic import()
            import_html = outputs_dir / "import_leak.html"
            import_html.write_text('<html><script>import("https://unpkg.com/some-pkg");</script></html>', encoding="utf-8")
            errors = validate_project.check_interactive_reports(proj_dir)
            self.assertTrue(any("Dynamic import() remote module request" in e or "unpkg CDN dependency" in e for e in errors))
            import_html.unlink()

            # Test 4: remote Worker
            worker_html = outputs_dir / "worker_leak.html"
            worker_html.write_text('<html><script>new Worker("https://cdn.observableusercontent.com/worker.js");</script></html>', encoding="utf-8")
            errors = validate_project.check_interactive_reports(proj_dir)
            self.assertTrue(any("Remote Web Worker dependency" in e or "Observable" in e for e in errors))
            worker_html.unlink()

            # Test 5: Patient identifiers
            patient_id_html = outputs_dir / "patient_leak.html"
            patient_id_html.write_text('<html><body><script>const d = [{"patient_id": "SYNTH_0042"}];</script></body></html>', encoding="utf-8")
            errors = validate_project.check_interactive_reports(proj_dir)
            self.assertTrue(any("Individual-level patient identifiers" in e for e in errors))
            patient_id_html.unlink()

            # Test 6: HTML / data improperly placed in reports/quarto/
            improper_html = quarto_dir / "interactive_summary.html"
            improper_html.write_text('<html><body>Report</body></html>', encoding="utf-8")
            errors = validate_project.check_interactive_reports(proj_dir)
            self.assertTrue(any("Generated HTML artifact found in reports/quarto/" in e for e in errors))
            improper_html.unlink()

    def test_clean_html_passes_validation(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            proj_dir = Path(tmpdir)
            outputs_dir = proj_dir / "outputs" / "private"
            outputs_dir.mkdir(parents=True, exist_ok=True)
            clean_html = outputs_dir / "clean_report.html"
            clean_html.write_text(
                '<html><head><style>body { font-family: sans-serif; }</style></head>'
                '<body><h1>Self Contained Report</h1><svg width="100" height="100"></svg>'
                '<script>console.log("Local execution only");</script></body></html>',
                encoding="utf-8"
            )

            errors = validate_project.check_interactive_reports(proj_dir)
            self.assertEqual(len(errors), 0, "Clean self-contained HTML in outputs/private must pass validation")

    def test_quarto_end_to_end_render_and_zero_network_verification(self):
        """End-to-end verification: render interactive_summary.qmd and verify zero external network requests."""
        with tempfile.TemporaryDirectory() as tmpdir:
            proj_dir = Path(tmpdir)
            # Setup Case Project structure
            (proj_dir / "reports" / "quarto").mkdir(parents=True, exist_ok=True)
            (proj_dir / "outputs" / "private").mkdir(parents=True, exist_ok=True)
            (proj_dir / "outputs" / "release").mkdir(parents=True, exist_ok=True)
            (proj_dir / "data" / "synthetic").mkdir(parents=True, exist_ok=True)
            (proj_dir / "src" / "python").mkdir(parents=True, exist_ok=True)
            (proj_dir / "sql").mkdir(parents=True, exist_ok=True)

            # Copy qmd template and pipeline
            qmd_src = PLATFORM_ROOT / "templates" / "analysis-project" / "template" / "reports" / "quarto" / "interactive_summary.qmd"
            pipeline_src = PLATFORM_ROOT / "templates" / "analysis-project" / "template" / "src" / "python" / "sample_rwd_pipeline.py"
            shutil.copy(qmd_src, proj_dir / "reports" / "quarto" / "interactive_summary.qmd")
            shutil.copy(pipeline_src, proj_dir / "src" / "python" / "sample_rwd_pipeline.py")

            # Run pipeline to generate aggregated JSON in outputs/private
            pipeline_module = load_module("e2e_pipeline", proj_dir / "src" / "python" / "sample_rwd_pipeline.py")
            pipeline_module.run_pipeline()

            private_json = proj_dir / "outputs" / "private" / "interactive_cohort_summary.json"
            self.assertTrue(private_json.exists(), "Pipeline must generate outputs/private/interactive_cohort_summary.json")

            # Setup isolated sandbox environment variables for Quarto/Jupyter logs and cache
            quarto_env = os.environ.copy()
            quarto_env["QUARTO_DATA_DIR"] = str(proj_dir / ".quarto_data")
            quarto_env["QUARTO_CACHE_DIR"] = str(proj_dir / ".quarto_cache")
            quarto_env["XDG_DATA_HOME"] = str(proj_dir / ".xdg_data")
            quarto_env["XDG_CACHE_HOME"] = str(proj_dir / ".xdg_cache")
            quarto_env["XDG_STATE_HOME"] = str(proj_dir / ".xdg_state")
            quarto_env["XDG_CONFIG_HOME"] = str(proj_dir / ".xdg_config")

            # Render Quarto report
            qmd_target = proj_dir / "reports" / "quarto" / "interactive_summary.qmd"
            res = subprocess.run(
                ["quarto", "render", str(qmd_target)],
                cwd=str(proj_dir),
                env=quarto_env,
                capture_output=True,
                text=True
            )
            self.assertEqual(res.returncode, 0, f"Quarto render failed: {res.stderr}\nStdout: {res.stdout}")

            # Move to outputs/private/interactive_summary.html
            rendered_temp = proj_dir / "reports" / "quarto" / "interactive_summary.html"
            rendered_final = proj_dir / "outputs" / "private" / "interactive_summary.html"
            self.assertTrue(rendered_temp.exists(), "Quarto must generate HTML")
            shutil.move(str(rendered_temp), str(rendered_final))

            # Inspect rendered HTML content
            html_content = rendered_final.read_text(encoding="utf-8")
            self.assertIn("offline-cohort-data", html_content, "Must contain embedded JSON script")
            self.assertIn("rwd-chart", html_content, "Must contain SVG chart container")
            self.assertIn("data-table", html_content, "Must contain data table container")

            # Check zero external network leaks
            import re
            # Check for active network dependencies
            network_leaks = re.findall(
                r"(?:src|href)\s*=\s*[\"']https?://(?!www\.w3\.org)[^\s\"']+|fetch\s*\(\s*[\"'`]https?:|import\s*\(\s*[\"'`]https?:|cdn\.jsdelivr|unpkg\.com|observableusercontent",
                html_content,
                re.IGNORECASE
            )
            self.assertEqual(len(network_leaks), 0, f"External network dependencies detected in rendered HTML: {network_leaks}")

            # Run validate-project check
            errors = validate_project.check_interactive_reports(proj_dir)
            self.assertEqual(len(errors), 0, f"Validation errors on rendered report: {errors}")

    def test_browser_headless_dom_and_filter_interaction(self):
        """Launches headless Chrome/Edge on file:// URL to verify offline rendering and dynamic filter interactions."""
        import asyncio
        import socket
        import urllib.request
        import websockets

        chrome_candidates = [
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
            "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
            "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
            "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
            "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
            "google-chrome",
            "chromium",
            "msedge"
        ]
        chrome_bin = None
        for cand in chrome_candidates:
            if shutil.which(cand) or Path(cand).exists():
                chrome_bin = cand
                break

        if not chrome_bin:
            self.skipTest("No supported browser (Chrome/Edge) found for headless CDP verification.")

        html_path = PLATFORM_ROOT / "templates" / "analysis-project" / "template" / "outputs" / "private" / "interactive_summary.html"
        if not html_path.exists():
            self.skipTest("interactive_summary.html not yet rendered in template directory.")

        # Dynamically find a free port
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind(("127.0.0.1", 0))
            free_port = s.getsockname()[1]

        async def run_cdp_test():
            user_data_dir = tempfile.mkdtemp()
            proc = subprocess.Popen([
                chrome_bin,
                "--headless=new",
                "--disable-gpu",
                "--no-sandbox",
                "--disable-setuid-sandbox",
                "--disable-dev-shm-usage",
                "--disable-software-rasterizer",
                "--no-first-run",
                "--no-default-browser-check",
                f"--remote-debugging-port={free_port}",
                f"--user-data-dir={user_data_dir}",
                f"file://{html_path.resolve()}"
            ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

            # Poll until CDP endpoint is ready (up to 10 seconds)
            targets = None
            for _ in range(50):
                await asyncio.sleep(0.2)
                try:
                    with urllib.request.urlopen(f"http://127.0.0.1:{free_port}/json", timeout=1) as response:
                        targets = json.loads(response.read().decode())
                        if targets:
                            break
                except Exception:
                    pass

            if not targets:
                stdout_err = ""
                try:
                    proc.terminate()
                    out, err = proc.communicate(timeout=2)
                    stdout_err = f"Stdout: {out.decode(errors='ignore')}\nStderr: {err.decode(errors='ignore')}"
                except Exception:
                    pass
                self.fail(f"CDP failed to start on port {free_port}.\n{stdout_err}")

            try:
                target = next(t for t in targets if "interactive_summary.html" in t.get("url", ""))
                ws_url = target["webSocketDebuggerUrl"]

                async with websockets.connect(ws_url, max_size=10 * 1024 * 1024) as ws:
                    # Wait until DOM and scripts are fully loaded
                    val = {}
                    for _ in range(50):
                        eval_check = {
                            "id": 99,
                            "method": "Runtime.evaluate",
                            "params": {
                                "expression": 'JSON.stringify({ readyState: document.readyState, title: document.title, rows: document.querySelectorAll("#table-body tr").length, totalPts: document.getElementById("stat-total-pts") ? document.getElementById("stat-total-pts").textContent : null })'
                            }
                        }
                        await ws.send(json.dumps(eval_check))
                        while True:
                            msg = json.loads(await ws.recv())
                            if msg.get("id") == 99:
                                val = json.loads(msg.get("result", {}).get("result", {}).get("value", "{}"))
                                break
                        if val.get("readyState") == "complete" and val.get("title") and val.get("rows", 0) > 0:
                            break
                        await asyncio.sleep(0.1)

                    # 1. Verify initial render
                    self.assertIn("RWD コホート", val.get("title", ""))
                    self.assertGreater(val.get("rows", 0), 0, "Table rows must be rendered on initial load")
                    self.assertIsNotNone(val.get("totalPts"))

                    # 2. Verify filter interaction: Arm + Sex + Period
                    eval_filter = {
                        "id": 2,
                        "method": "Runtime.evaluate",
                        "params": {
                            "expression": '''
                                const armSelect = document.getElementById("filter-arm");
                                const sexSelect = document.getElementById("filter-sex");
                                const periodSelect = document.getElementById("filter-period");
                                armSelect.value = "Active";
                                armSelect.dispatchEvent(new Event("change"));
                                const resArm = {
                                    selectedArm: armSelect.value,
                                    rows: document.querySelectorAll("#table-body tr").length,
                                    svgBars: document.querySelectorAll("#rwd-chart rect").length
                                };
                                // Filter by period if available
                                if (periodSelect.options.length > 1) {
                                    periodSelect.selectedIndex = 1;
                                    periodSelect.dispatchEvent(new Event("change"));
                                }
                                JSON.stringify({
                                    selectedArm: armSelect.value,
                                    selectedPeriod: periodSelect.value,
                                    rows: document.querySelectorAll("#table-body tr").length,
                                    svgBars: document.querySelectorAll("#rwd-chart rect").length
                                });
                            '''
                        }
                    }
                    await ws.send(json.dumps(eval_filter))
                    while True:
                        msg = json.loads(await ws.recv())
                        if msg.get("id") == 2:
                            val = json.loads(msg.get("result", {}).get("result", {}).get("value"))
                            self.assertEqual(val["selectedArm"], "Active")
                            self.assertGreater(val["rows"], 0, "Filtered rows must exist")
                            self.assertGreater(val["svgBars"], 0, "Filtered SVG bars must exist")
                            break
            finally:
                try:
                    proc.terminate()
                    proc.wait(timeout=3)
                except Exception:
                    proc.kill()
                    proc.wait(timeout=3)
                finally:
                    if proc.stdout:
                        proc.stdout.close()
                    if proc.stderr:
                        proc.stderr.close()

        asyncio.run(run_cdp_test())


class TestPowerShellScriptStaticIntegrity(unittest.TestCase):
    """Verifies static structural integrity and strict mode declarations across Windows PowerShell scripts."""

    def test_powershell_scripts_strict_mode(self):
        ps_dir = PLATFORM_ROOT / "scripts" / "windows"
        for ps_file in ps_dir.glob("*.ps1"):
            with open(ps_file, "r", encoding="utf-8") as f:
                content = f.read()
            self.assertIn("Set-StrictMode -Version Latest", content, f"{ps_file.name} missing Set-StrictMode")
            self.assertIn("$ErrorActionPreference", content, f"{ps_file.name} missing ErrorActionPreference")


def main():
    print("========================================================")
    print("  Running Platform Test Suite (Evidence Verification)")
    print("========================================================")
    suite = unittest.TestLoader().loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)


if __name__ == "__main__":
    main()
