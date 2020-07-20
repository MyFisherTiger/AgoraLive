//
//  PlayerVM.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/4/27.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay

typealias Speaker = MediaKit.Speaker

class PlayerVM: RxObject {
    var activeSpeaker = PublishRelay<Speaker>()
    
    override init() {
        super.init()
        self.observe()
    }
    
    func startRenderLocalVideoStream(id: Int, view: UIView) {
        let mediaKit = ALCenter.shared().centerProvideMediaHelper()
        mediaKit.player.startRenderLocalVideoStream(id: id, view: view)
    }
    
    func startRenderRemoteVideoStream(id: Int, view: UIView) {
        let mediaKit = ALCenter.shared().centerProvideMediaHelper()
        mediaKit.player.startRenderRemoteVideoStream(id: id, view: view)
    }
    
    func renderRemoteVideoStream(id: Int, superResolution action: AGESwitch) {
        let mediaKit = ALCenter.shared().centerProvideMediaHelper()
        mediaKit.player.renderRemoteVideoStream(id: id, superResolution: action)
    }
}

private extension PlayerVM {
    func observe() {
        let media = ALCenter.shared().centerProvideMediaHelper()
        media.activeSpeaker.bind(to: self.activeSpeaker).disposed(by: bag)
    }
}
