#!/usr/bin/env swift
// PhotoAxis-owned vector paths. No stock, Adobe assets, bundled fonts or AI bitmap.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let args = CommandLine.arguments
 guard args.count == 2 else { fatalError("Usage: generate-app-icon.swift output.iconset") }
let root = URL(fileURLWithPath:args[1]); try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
let srgb = CGColorSpace(name:CGColorSpace.sRGB)!
func color(_ r:CGFloat,_ g:CGFloat,_ b:CGFloat) -> CGColor { CGColor(colorSpace:srgb,components:[r,g,b,1])! }
for points in [16,32,128,256,512] { for scale in [1,2] {
    let pixels=points*scale, c=CGContext(data:nil,width:pixels,height:pixels,bitsPerComponent:8,bytesPerRow:pixels*4,space:srgb,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.scaleBy(x:CGFloat(pixels)/1024,y:CGFloat(pixels)/1024)
    c.addPath(CGPath(roundedRect:CGRect(x:56,y:56,width:912,height:912),cornerWidth:196,cornerHeight:196,transform:nil))
    c.clip(); c.setFillColor(color(0.06,0.09,0.14)); c.fill(CGRect(x:0,y:0,width:1024,height:1024))
    let gradient=CGGradient(colorsSpace:srgb,colors:[color(0.11,0.21,0.29),color(0.025,0.045,0.08)] as CFArray,locations:[0,1])!
    c.drawLinearGradient(gradient,start:CGPoint(x:120,y:940),end:CGPoint(x:900,y:80),options:[])
    c.setLineCap(.round); c.setLineJoin(.round)
    // Perspective quadrilateral inside orthogonal editing axes.
    c.setFillColor(color(0.12,0.49,0.56)); c.setStrokeColor(color(0.23,0.82,0.79)); c.setLineWidth(32)
    c.move(to:CGPoint(x:285,y:300));c.addLine(to:CGPoint(x:780,y:360));c.addLine(to:CGPoint(x:705,y:755));c.addLine(to:CGPoint(x:345,y:700));c.closePath();c.drawPath(using:.fillStroke)
    c.setStrokeColor(color(0.98,0.71,0.30));c.setLineWidth(36)
    c.move(to:CGPoint(x:245,y:775));c.addLine(to:CGPoint(x:245,y:245));c.addLine(to:CGPoint(x:800,y:245));c.strokePath()
    c.setFillColor(color(0.97,0.97,0.93))
    for p in [CGPoint(x:285,y:300),CGPoint(x:780,y:360),CGPoint(x:705,y:755),CGPoint(x:345,y:700)] {c.fillEllipse(in:CGRect(x:p.x-28,y:p.y-28,width:56,height:56))}
    let name="icon_\(points)x\(points)"+(scale==2 ? "@2x" : "")+".png", url=root.appendingPathComponent(name)
    let destination=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil)!
    CGImageDestinationAddImage(destination,c.makeImage()!,nil)
    guard CGImageDestinationFinalize(destination) else {fatalError("PNG encoding failed")}
}}
print("Generated PhotoAxis-owned iconset")
