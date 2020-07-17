//
//  RoomSettings.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/3/9.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import AgoraRtcKit

struct LocalLiveSettings {
    struct Beauty {
        var lighteningLevel: CGFloat = 0.7
        var smoothnessLevel: CGFloat = 0.5
        var rednessLevel: CGFloat = 0.1
    }
    
    struct VideoConfiguration {
        var resolution: CGSize = AgoraVideoDimension640x360
        var frameRate: AgoraVideoFrameRate = .fps15
        var bitRate: Int = AgoraVideoBitrateStandard
    }
    
    var title: String
    var beauty = Beauty()
    var media = VideoConfiguration()
}
