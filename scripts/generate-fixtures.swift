// Self-authored deterministic geometry/color samples. No external images or fonts.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = CommandLine.arguments.count > 1 ? URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true) : root.appendingPathComponent("Fixtures/Generated", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let width = 640, height = 480
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
let p3 = CGColorSpace(name: CGColorSpace.displayP3)!
var records: [[String: Any]] = []

func image(_ pixels: [UInt8], space: CGColorSpace = srgb) -> CGImage {
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                   bytesPerRow: width * 4, space: space,
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}

func write(_ name: String, pixels: [UInt8], space: CGColorSpace = srgb,
           type: UTType = .png, orientation: Int = 1) throws {
    let url = output.appendingPathComponent(name)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)!
    let properties: [CFString: Any] = [kCGImagePropertyOrientation: orientation,
                                      kCGImageDestinationLossyCompressionQuality: 0.95]
    CGImageDestinationAddImage(destination, image(pixels, space: space), properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { fatalError("Encode failed: \(name)") }
    let data = try Data(contentsOf: url)
    let source = CGImageSourceCreateWithData(data as CFData, nil)!
    let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary
    precondition(props[kCGImagePropertyPixelWidth] as? Int == width)
    precondition(props[kCGImagePropertyPixelHeight] as? Int == height)
    if orientation != 1 { precondition(props[kCGImagePropertyOrientation] as? Int == orientation) }
    records.append(["file": name, "width": width, "height": height, "orientation": orientation,
                    "colorSpace": space.name! as String, "bytes": data.count,
                    "sha256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()])
}

var grid = [UInt8](repeating: 255, count: width * height * 4)
var alpha = [UInt8](repeating: 0, count: width * height * 4)
var colors = grid
for y in 0..<height {
    for x in 0..<width {
        let offset = (y * width + x) * 4
        let line = x % 40 < 2 || y % 40 < 2
        var color: [UInt8] = line ? [70, 70, 70, 255] : [235, 235, 235, 255]
        if x < 80 && y < 80 { color = [255, 0, 0, 255] }
        if x >= width - 80 && y < 80 { color = [0, 255, 0, 255] }
        if x >= width - 80 && y >= height - 80 { color = [0, 0, 255, 255] }
        if x < 80 && y >= height - 80 { color = [255, 255, 0, 255] }
        grid.replaceSubrange(offset..<offset+4, with: color)
        let distance = hypot(Double(x) + 0.5 - 320, Double(y) + 0.5 - 240)
        let a = UInt8((max(0, min(1, (180 - distance) / 24)) * 255).rounded())
        alpha.replaceSubrange(offset..<offset+4, with: [a, 0, 0, a])
        colors.replaceSubrange(offset..<offset+4, with: [UInt8(x * 255 / (width - 1)), UInt8(y * 255 / (height - 1)), 64, 255])
    }
}
try write("grid-corners.png", pixels: grid)
try write("alpha-edges.png", pixels: alpha)
try write("grid-exif-6.jpg", pixels: grid, type: .jpeg, orientation: 6)
try write("colors-srgb.png", pixels: colors)
try write("colors-display-p3.png", pixels: colors, space: p3)
let vietnamese = "PhotoAxis — Tiếng Việt\nẢnh phố biển, đường chân trời.\nẮ ằ ễ ộ ứ ỵ Đ đ\nTên lớp: Ảnh nền — chưa lưu\n"
try vietnamese.write(to: output.appendingPathComponent("chữ-tiếng-Việt.txt"), atomically: true, encoding: .utf8)
let truncated = try Data(contentsOf: output.appendingPathComponent("grid-corners.png")).prefix(24)
try truncated.write(to: output.appendingPathComponent("invalid-truncated.png"))
let manifest: [String: Any] = ["generator": "scripts/generate-fixtures.swift", "provenance": "Self-authored; no personal data",
                               "corners": ["TL": "red", "TR": "green", "BR": "blue", "BL": "yellow"],
                               "images": records]
try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    .write(to: output.appendingPathComponent("manifest.json"))
print("PASS: generated and re-read metadata for \(records.count) images; text and corrupt PNG included")
print(output.path)
