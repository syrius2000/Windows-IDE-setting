import Foundation
import Vision
import AppKit

struct RecognizedBlock: Codable {
    let text: String
    let confidence: Float
    let bbox: BoundingBox
}

struct BoundingBox: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct OcrOutput: Codable {
    let image_path: String
    let blocks: [RecognizedBlock]
    let total_blocks: Int
}

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: vision-ocr <image-path>\n", stderr)
    exit(1)
}

let imagePath = CommandLine.arguments[1]
let imageURL = URL(fileURLWithPath: imagePath)

guard let nsImage = NSImage(contentsOf: imageURL),
      let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("[ERROR] Could not load image from: \(imagePath)\n", stderr)
    exit(2)
}

var blocks: [RecognizedBlock] = []

let request = VNRecognizeTextRequest { (request, error) in
    if let error = error {
        fputs("[ERROR] Vision request failed: \(error.localizedDescription)\n", stderr)
        return
    }
    
    guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
    
    for observation in observations {
        guard let topCandidate = observation.topCandidates(1).first else { continue }
        
        let box = observation.boundingBox
        let b = BoundingBox(
            x: Double(box.origin.x),
            y: Double(box.origin.y),
            width: Double(box.size.width),
            height: Double(box.size.height)
        )
        
        blocks.append(RecognizedBlock(
            text: topCandidate.string,
            confidence: topCandidate.confidence,
            bbox: b
        ))
    }
}

request.recognitionLevel = .accurate
request.usesLanguageCorrection = true
request.recognitionLanguages = ["ja-JP", "en-US"]

let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
do {
    try handler.perform([request])
    let output = OcrOutput(
        image_path: imagePath,
        blocks: blocks,
        total_blocks: blocks.count
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    let data = try encoder.encode(output)
    if let jsonString = String(data: data, encoding: .utf8) {
        print(jsonString)
    }
} catch {
    fputs("[ERROR] Failed to perform Vision recognition: \(error.localizedDescription)\n", stderr)
    exit(3)
}
