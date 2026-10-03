import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import AVFoundation

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Fixtures/P17")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let width = 1600, height = 640
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
for (index, text) in ["HỒ SƠ ĐIỀU TRA", "Tài liệu kiểm thử tiếng Việt", "Không suy đoán phần không đọc được", "DỮ LIỆU NGOÀI VÙNG OCR"].enumerated() {
    let attrs: [NSAttributedString.Key: Any] = [.init(kCTFontAttributeName as String): CTFontCreateWithName("Arial" as CFString, 60, nil), .init(kCTForegroundColorAttributeName as String): CGColor(red: 0, green: 0, blue: 0, alpha: 1)]
    context.textPosition = CGPoint(x: 60, y: height - (120 + index * 140))
    CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs)), context)
}
let png = output.appendingPathComponent("ocr-tieng-viet.png")
let dest = CGImageDestinationCreateWithURL(png as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(dest))
let movie = output.appendingPathComponent("video-vfr-rotated.mov")
if FileManager.default.fileExists(atPath: movie.path) { try FileManager.default.removeItem(at: movie) }
let writer = try AVAssetWriter(outputURL: movie, fileType: .mov)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 200, AVVideoCompressionPropertiesKey: [AVVideoAllowFrameReorderingKey: false]])
input.mediaTimeScale = 1000; input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 200, ty: 0)
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 200])
writer.add(input); precondition(writer.startWriting()); writer.startSession(atSourceTime: .zero)
let colors: [(UInt8, UInt8, UInt8)] = [(0,0,255),(0,255,0),(255,0,0),(0,255,255)]
let times: [Int64] = [0,100,350,900]
for i in 0..<4 {
    var tries = 0
    while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(10)); tries += 1; precondition(tries < 1000) }
    var buffer: CVPixelBuffer?
    precondition(CVPixelBufferCreate(kCFAllocatorDefault, 320, 200, kCVPixelFormatType_32BGRA, [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer) == kCVReturnSuccess)
    let pixels = buffer!; CVPixelBufferLockBaseAddress(pixels, [])
    let base = CVPixelBufferGetBaseAddress(pixels)!.assumingMemoryBound(to: UInt8.self), stride = CVPixelBufferGetBytesPerRow(pixels)
    for y in 0..<200 { for x in 0..<320 { let p = y * stride + x * 4; base[p] = colors[i].0; base[p + 1] = colors[i].1; base[p + 2] = colors[i].2; base[p + 3] = 255 } }
    CVPixelBufferUnlockBaseAddress(pixels, [])
    precondition(adaptor.append(pixels, withPresentationTime: CMTime(value: times[i], timescale: 1000)))
}
input.markAsFinished(); await writer.finishWriting(); precondition(writer.status == .completed, String(describing: writer.error))
let description = "Synthetic fixtures only. OCR: Arial 60pt, 1600x640, four Vietnamese lines. Video: 320x200 H.264, 90-degree track transform, four red/green/blue/yellow presentation samples at 0/100/350/900 ms. No real case or personal data.\n"
try description.write(to: output.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
print(output.path)
