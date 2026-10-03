import CoreImage
import CoreGraphics
import PhotoAxisCore

enum PaintRasterizer {
    /// Only allocate the stroke's bounded ROI, with reduced sampling during pointer interaction.
    /// A grayscale union mask applies opacity once per stroke, avoiding dark dab overlaps.
    static func image(_ paint: PaintContent, sources: [String: CGImage], samplingScale: Double = 1) throws -> CIImage {
        try paint.validate()
        let canvas = CGRect(x:0,y:0,width:paint.size.width,height:paint.size.height)
        var output = CIImage(color:CIColor(red:0,green:0,blue:0,alpha:0)).cropped(to:canvas)
        let scale = min(1,max(1.0/64,samplingScale))
        for stroke in paint.strokes where stroke.opacity > 0 {
            try Task.checkCancellation()
            let box = stroke.bounds(in:paint.size), w = max(1,Int(ceil(box.width*scale))), h = max(1,Int(ceil(box.height*scale)))
            guard let mask = CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w,
                                       space:CGColorSpace(name:CGColorSpace.linearGray)!,bitmapInfo:0) else { throw ImageImportError.unreadable }
            mask.scaleBy(x:Double(w)/box.width,y:Double(h)/box.height)
            mask.setBlendMode(.lighten); mask.setFillColor(gray:1,alpha:1)
            let gradient = CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.linearGray)!,colors:[CGColor(gray:1,alpha:1),CGColor(gray:0,alpha:1)] as CFArray,locations:[0,1])!
            let radius = stroke.diameter/2
            for (index,p) in stroke.samples().enumerated() {
                if index % 128 == 0 { try Task.checkCancellation() }
                let center = CGPoint(x:p.x-box.x,y:box.height-(p.y-box.y))
                if stroke.hardness >= 0.999 {
                    mask.fillEllipse(in:CGRect(x:center.x-radius,y:center.y-radius,width:radius*2,height:radius*2))
                } else {
                    mask.drawRadialGradient(gradient,startCenter:center,startRadius:radius*stroke.hardness,
                                            endCenter:center,endRadius:radius,options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
                }
            }
            guard let bitmap = mask.makeImage() else { throw ImageImportError.unreadable }
            let regionMask = CIImage(cgImage:bitmap).transformed(by:CGAffineTransform(scaleX:box.width/Double(w),y:box.height/Double(h)))
                .transformed(by:CGAffineTransform(translationX:box.x,y:Double(paint.size.height)-box.y-box.height))
            let ink: CIImage
            switch stroke.kind {
            case .brush: ink = CIImage(color:CIColor(cgColor:ContentRasterizer.color(stroke.color))).cropped(to:canvas)
            case .clone:
                guard let id = stroke.sourceID, let source = sources[id], let offset = stroke.sourceOffset else { throw DocumentError.missingSource }
                ink = CIImage(cgImage:source).transformed(by:CGAffineTransform(translationX:-offset.x,y:Double(paint.size.height-source.height)+offset.y)).cropped(to:canvas)
            }
            let visible = ink.applyingFilter("CIBlendWithMask",parameters:["inputBackgroundImage":CIImage(color:CIColor(red:0,green:0,blue:0,alpha:0)).cropped(to:regionMask.extent),"inputMaskImage":regionMask])
                .applyingFilter("CIColorMatrix",parameters:["inputAVector":CIVector(x:0,y:0,z:0,w:stroke.opacity)]).cropped(to:regionMask.extent)
            output = visible.composited(over:output).cropped(to:canvas)
        }
        return output
    }
}
