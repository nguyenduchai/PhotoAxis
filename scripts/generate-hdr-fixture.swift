import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers
let root=URL(fileURLWithPath:CommandLine.arguments.count>1 ? CommandLine.arguments[1] : FileManager.default.temporaryDirectory.appendingPathComponent("PhotoAxis-HDR-QA").path)
try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
let linear=CGColorSpace(name:CGColorSpace.extendedLinearSRGB)!
let floats=(0..<(64*64)).flatMap { _ -> [Float] in [3.0,1.2,0.4,1.0] }
let bytes=floats.withUnsafeBytes { Data($0) }
let provider=CGDataProvider(data:bytes as CFData)!
let info=CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue).union([.floatComponents,.byteOrder32Little])
let image=CGImage(headroom:3,width:64,height:64,bitsPerComponent:32,bitsPerPixel:128,bytesPerRow:64*16,space:linear,bitmapInfo:info,provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
print("image",image.bitsPerComponent,image.contentHeadroom,image.calculatedContentHeadroom)
for (name,request) in [("iso-hdr",kCGImageDestinationEncodeToISOHDR),("iso-gainmap",kCGImageDestinationEncodeToISOGainmap)] {
 let url=root.appendingPathComponent(name+".heic")
 let destination=CGImageDestinationCreateWithURL(url as CFURL,UTType.heic.identifier as CFString,1,nil)!
 CGImageDestinationAddImage(destination,image,[kCGImageDestinationEncodeRequest:request] as CFDictionary)
 print(name,CGImageDestinationFinalize(destination))
 if let source=CGImageSourceCreateWithURL(url as CFURL,nil) {
  print("properties",CGImageSourceCopyPropertiesAtIndex(source,0,nil)!)
  print("aux",CGImageSourceCopyAuxiliaryDataInfoAtIndex(source,0,kCGImageAuxiliaryDataTypeISOGainMap) != nil,CGImageSourceCopyAuxiliaryDataInfoAtIndex(source,0,kCGImageAuxiliaryDataTypeHDRGainMap) != nil)
  if let hdr=CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldAllowFloat:true,kCGImageSourceDecodeRequest:kCGImageSourceDecodeToHDR] as CFDictionary) {print("decodedHDR",hdr.contentHeadroom,hdr.calculatedContentHeadroom)}
 }
}
