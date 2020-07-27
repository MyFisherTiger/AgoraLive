//
//  deviceVM.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/4/18.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import AGECamera

class MediaDeviceVM: NSObject {
    var camera: AGESwitch {
        get {
            let mediaKit = ALCenter.shared().centerProvideMediaHelper()
            return mediaKit.capture.video
        }
        
        set {
            let mediaKit = ALCenter.shared().centerProvideMediaHelper()
            try? mediaKit.capture.video(newValue)
        }
    }
    
    var cameraPosition: AGECamera.Position {
        get {
            let mediaKit = ALCenter.shared().centerProvideMediaHelper()
            return mediaKit.capture.cameraPostion
        }
        
        set {
            let mediaKit = ALCenter.shared().centerProvideMediaHelper()
            mediaKit.capture.cameraPostion = newValue
        }
    }
    
    var mic: AGESwitch {
        get {
            let mediaKit = ALCenter.shared().centerProvideMediaHelper()
            return mediaKit.capture.audio
        }
        
        set {
            let mediaKit = ALCenter.shared().centerProvideMediaHelper()
            mediaKit.capture.audio = newValue
        }
    }
    
    var localAudioLoop: AGESwitch {
        get {
            let mediaKit = ALCenter.shared().centerProvideMediaHelper()
            return mediaKit.player.isLocalAudioLoop ? .on : .off
        }
        
        set {
            let mediaKit = ALCenter.shared().centerProvideMediaHelper()
            mediaKit.player.localInputAudioLoop(newValue)
        }
    }
    
    var audioOutput: BehaviorRelay<AudioOutputRouting> = BehaviorRelay(value: AudioOutputRouting.default)
    
    func audioLoop(_ action: AGESwitch) {
        let mediaKit = ALCenter.shared().centerProvideMediaHelper()
        mediaKit.player.localInputAudioLoop(action)
    }
    
    func switchCamera() {
        let mediaKit = ALCenter.shared().centerProvideMediaHelper()
        try? mediaKit.capture.switchCamera()
    }
    
    func cameraResolution(_ resolution: AVCaptureSession.Preset) {
        let mediaKit = ALCenter.shared().centerProvideMediaHelper()
        mediaKit.capture.videoResolution(.high)
    }
    
    override init() {
        super.init()
        
        let mediaKit = ALCenter.shared().centerProvideMediaHelper()
        mediaKit.player.addEvent(.audioOutputRouting({ [weak self] (route) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.audioOutput.accept(route)
        }), observer: self)
    }
}
