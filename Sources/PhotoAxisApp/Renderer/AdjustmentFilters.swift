import CoreImage
import PhotoAxisCore

enum AdjustmentFilters {
    static func apply(_ adjustments: ImageAdjustments, to source: CIImage) throws -> CIImage {
        try adjustments.validate()
        guard adjustments.enabled,!adjustments.isNeutral else {return source}
        var image=source
        if adjustments.exposure != 0 {image=image.applyingFilter("CIExposureAdjust",parameters:["inputEV":adjustments.exposure])}
        if adjustments.brightness != 0 || adjustments.contrast != 0 {
            image=image.applyingFilter("CIColorControls",parameters:["inputBrightness":adjustments.brightness/100,"inputContrast":1+adjustments.contrast/100,"inputSaturation":1])
        }
        if adjustments.saturation != 0 {
            image=image.applyingFilter("CIColorControls",parameters:["inputBrightness":0,"inputContrast":1,"inputSaturation":1+adjustments.saturation/100])
        }
        return image.cropped(to:source.extent)
    }
}
