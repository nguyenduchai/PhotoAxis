import AppKit
import PhotoAxisCore

struct CropState {
    var region:CropRegion
    // Numeric edits fit against the last gesture/reset, not each intermediate
    // keystroke's preview. Otherwise entering 160 can shrink through 1 and 16.
    var configurationBasis:CropRegion?
    var previousTool:ToolKind = .hand
    var preset=0
    var widthText="",heightText=""
    var ratio:Double?
    var output:CanvasSize?
    var grid=true
    var isValid=true
    var isConfigurationValid=true
}

extension PhotoDocument {
    func startCrop() throws {
        if cropSession != nil {return}
        guard resolveSession(),!isInteractionLocked else{throw DocumentError.activeSession}
        cropSession=CropState(region:.full(model.canvas),previousTool:activeTool,widthText:String(model.canvas.width),heightText:String(model.canvas.height))
        changed?()
    }
    func configureCrop(preset:Int,width:String,height:String) {
        guard var state=cropSession else{return}
        state.preset=preset;state.widthText=width;state.heightText=height
        state.isConfigurationValid=false
        do {
            state.output=nil
            let ratios:[Double?]=[nil,Double(model.canvas.width)/Double(model.canvas.height),1,4.0/3,3.0/2,16.0/9,210.0/297]
            if preset < ratios.count { state.ratio=ratios[preset] }
            else if preset == 7 {
                guard let w=DocumentNumber.parse(width,language:Locale.current.identifier),let h=DocumentNumber.parse(height,language:Locale.current.identifier),w>0,h>0 else{throw DocumentError.invalidValue}
                state.ratio=w/h
            } else {
                guard let w=Int(width),let h=Int(height) else{throw DocumentError.invalidValue}
                let size=try CanvasSize(width:w,height:h);state.output=size;state.ratio=Double(w)/Double(h)
            }
            if let ratio=state.ratio {guard ratio.isFinite,ratio>0 else{throw DocumentError.invalidValue}}
            state.isConfigurationValid=true
            let basis=state.configurationBasis ?? state.region
            state.configurationBasis=basis
            let region=basis.fitted(ratio:state.ratio,in:model.canvas)
            try region.validate(in:model.canvas)
            var candidate=model;try candidate.crop(to:region,output:state.output)
            state.region=region
            state.isValid=true
        } catch { state.isValid=false }
        cropSession=state;changed?()
    }
    func moveCrop(to region:CropRegion) {
        guard var state=cropSession else{return}
        do {
            try region.validate(in:model.canvas)
            var candidate=model;try candidate.crop(to:region,output:state.output)
            state.region=region;state.configurationBasis=region;state.isValid=state.isConfigurationValid
        } catch {state.isValid=false}
        cropSession=state;changed?()
    }
    func resetCrop() {
        guard var state=cropSession else{return}
        state.configurationBasis=CropRegion.full(model.canvas)
        cropSession=state;configureCrop(preset:state.preset,width:state.widthText,height:state.heightText)
    }
    func swapCrop() {
        guard let state=cropSession else{return}
        if state.preset >= 7 {configureCrop(preset:state.preset,width:state.heightText,height:state.widthText)}
        else if state.ratio != nil {
            let values=[1:(model.canvas.height,model.canvas.width),2:(1,1),3:(3,4),4:(2,3),5:(9,16),6:(297,210)]
            if let (w,h)=values[state.preset] {configureCrop(preset:7,width:String(w),height:String(h))}
        }
        else {moveCrop(to:CropRegion(x:state.region.x,y:state.region.y,width:min(state.region.height,Double(model.canvas.width)-state.region.x),height:min(state.region.width,Double(model.canvas.height)-state.region.y)))}
    }
}
