import CoreText
import CoreGraphics
import Foundation
import PhotoAxisCore

/// Core Text/Core Graphics only: safe to use on the serial image worker. Bitmaps
/// are transient render products; the document always retains typed content.
enum ContentRasterizer {
    static let srgb=CGColorSpace(name:CGColorSpace.sRGB)!
    static func color(_ color:RGBAColor)->CGColor {CGColor(colorSpace:srgb,components:[color.red,color.green,color.blue,color.alpha])!}
    static func font(_ text:TextContent)->CTFont {CTFontCreateWithName(text.fontName as CFString,text.fontSize,nil)}
    static func missingFont(_ text:TextContent)->Bool {CTFontCopyPostScriptName(font(text)) as String != text.fontName}
    struct Layout {
        let lines:[CTLine],widths:[Double],ascent:Double,step:Double,padding:Double,size:CanvasSize
    }
    static func layout(_ text:TextContent)throws->Layout {
        try text.validate()
        let parts=text.text.replacingOccurrences(of:"\r\n",with:"\n").replacingOccurrences(of:"\r",with:"\n").components(separatedBy:"\n")
        guard parts.count<=8000 else{throw DocumentError.invalidValue}
        let f=font(text),attributes:[NSAttributedString.Key:Any]=[NSAttributedString.Key(kCTFontAttributeName as String):f,NSAttributedString.Key(kCTForegroundColorAttributeName as String):color(text.color)]
        let lines=parts.map{CTLineCreateWithAttributedString(NSAttributedString(string:$0,attributes:attributes))}
        var ascent=Double(CTFontGetAscent(f)),descent=Double(CTFontGetDescent(f)),leading=Double(CTFontGetLeading(f)),widths:[Double]=[],padding=max(2,ceil(text.fontSize/4))
        for line in lines {
            var a:CGFloat=0,d:CGFloat=0,l:CGFloat=0
            let width=CTLineGetTypographicBounds(line,&a,&d,&l),ink=CTLineGetBoundsWithOptions(line,[.useGlyphPathBounds])
            ascent=max(ascent,Double(a),Double(ink.maxY));descent=max(descent,Double(d),Double(-ink.minY));leading=max(leading,Double(l))
            padding=max(padding,Double(-ink.minX),Double(ink.maxX)-width);widths.append(width)
        }
        padding=ceil(padding)+1
        let step=ceil(ascent+descent+leading)+text.lineSpacing
        let w=ceil((widths.max() ?? 0)+padding*2),h=ceil(ascent+descent+Double(max(0,lines.count-1))*step+padding*2)
        guard w.isFinite,h.isFinite,w<=8000,h<=8000 else{throw DocumentError.invalidValue}
        let size=try CanvasSize(width:max(1,Int(w)),height:max(1,Int(h)))
        return Layout(lines:lines,widths:widths,ascent:ascent,step:step,padding:padding,size:size)
    }
    static func measured(_ text:TextContent)throws->TextContent {var value=text;value.layoutSize=try layout(text).size;return value}
    static func context(_ size:CanvasSize)throws->CGContext {
        guard let c=CGContext(data:nil,width:size.width,height:size.height,bitsPerComponent:8,bytesPerRow:size.width*4,space:srgb,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue) else{throw ImageImportError.unreadable}
        return c
    }
    static func textImage(_ text:TextContent)throws->CGImage {
        let layout=try layout(text),c=try context(text.layoutSize),w=Double(text.layoutSize.width),h=Double(text.layoutSize.height)
        c.textMatrix = .identity
        for (i,line) in layout.lines.enumerated() {
            let x:Double
            switch text.alignment {case .left:x=layout.padding;case .center:x=(w-layout.widths[i])/2;case .right:x=w-layout.padding-layout.widths[i]}
            c.textPosition=CGPoint(x:x,y:h-layout.padding-layout.ascent-Double(i)*layout.step);CTLineDraw(line,c)
        }
        guard let image=c.makeImage() else{throw ImageImportError.unreadable};return image
    }
    static func shapeImage(_ shape:ShapeContent)throws->CGImage {
        try shape.validate();let c=try context(shape.size),w=Double(shape.size.width),h=Double(shape.size.height)
        let inset=min(shape.strokeWidth/2,min(w,h)/2),rect=CGRect(x:inset,y:inset,width:max(0,w-inset*2),height:max(0,h-inset*2))
        c.setFillColor(color(shape.fill));c.setStrokeColor(color(shape.stroke));c.setLineWidth(shape.strokeWidth);c.setLineJoin(.round);c.setLineCap(.round)
        if shape.kind == .line {
            func point(_ p:Point2D)->CGPoint {.init(x:inset+p.x*rect.width,y:h-inset-p.y*rect.height)}
            c.move(to:point(shape.lineStart));c.addLine(to:point(shape.lineEnd));if shape.strokeWidth>0{c.strokePath()}
        } else {
            if shape.kind == .ellipse {c.addEllipse(in:rect)}else{c.addRect(rect)}
            c.drawPath(using:shape.strokeWidth>0 ? .fillStroke:.fill)
        }
        guard let image=c.makeImage() else{throw ImageImportError.unreadable};return image
    }
}
