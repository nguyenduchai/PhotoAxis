// Re-run with: xcrun swift <this-file> <P15-native-evidence-directory>
// Uses only the exported synthetic files; does not drive the app or modify them.
import Foundation
import ImageIO
import CoreGraphics

precondition(CommandLine.arguments.count == 2)
let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let specifications: [(String, Int, Int, Double)] = [
    ("native-png-original-256.png", 256, 192, 300),
    ("native-jpeg-200.jpg", 200, 150, 72),
    ("final-perspective.png", 400, 300, 144),
    ("final-edited-en.png", 400, 300, 144),
    ("final-edited-en.jpg", 200, 150, 72),
    ("final-edited-reopened-vi.png", 400, 300, 144)
]
var entries = [[String: Any]]()
for (name, width, height, ppi) in specifications {
    let url = base.appendingPathComponent(name)
    let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary
    let horizontalPPI = (properties[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? 0
    let verticalPPI = (properties[kCGImagePropertyDPIHeight] as? NSNumber)?.doubleValue ?? 0
    let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
    let png = name.hasSuffix(".png")
    let bytes = try Data(contentsOf: url)
    precondition(image.width == width && image.height == height && image.bitsPerComponent == 8)
    precondition(abs(horizontalPPI - ppi) < 0.03 && abs(verticalPPI - ppi) < 0.03)
    precondition(properties[kCGImagePropertyGPSDictionary] == nil && orientation == 1)
    precondition(image.colorSpace?.copyICCData() != nil)
    precondition(bytes.range(of: Data((png ? "iCCP" : "ICC_PROFILE\0").utf8)) != nil)
    precondition(png ? image.alphaInfo == .last : image.alphaInfo == .noneSkipLast)
    entries.append([
        "file": name, "width": width, "height": height, "bitsPerComponent": 8,
        "ppi": horizontalPPI, "orientation": orientation,
        "profile": properties[kCGImagePropertyProfileName] ?? "",
        "alphaInfo": image.alphaInfo.rawValue, "GPSAbsent": true, "ICCEmbedded": true
    ])
}
func pixels(_ name: String) -> Data {
    let source = CGImageSourceCreateWithURL(base.appendingPathComponent(name) as CFURL, nil)!
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
    var bytes = Data(count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { storage in
        let context = CGContext(data: storage.baseAddress, width: image.width, height: image.height,
                                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return bytes
}
precondition(pixels("final-edited-en.png") == pixels("final-edited-reopened-vi.png"))
let report: [String: Any] = [
    "status": "PASS", "exports": entries,
    "editedProjectNativeEnglishAndVietnameseExportRGBAByteIdentical": true,
    "releaseUUIDForFinalExports": "D54A11BC-024A-3419-B64C-9D70715C2ED9",
    "scope": "actual native outputs; earlier two exports are UUID667, four final outputs UUIDD54; camera HDR and real IME remain separate"
]
let output = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
print(String(data: output, encoding: .utf8)!)
