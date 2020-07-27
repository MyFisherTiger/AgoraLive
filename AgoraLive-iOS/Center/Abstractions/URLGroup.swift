//
//  URLGroup.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/3/9.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit

struct URLGroup {
    #if PREPRODUCT
    private static let host = "http://api-solutions-pre.sh.agoralab.co/"
    #elseif PRODUCT
    private static let host = "http://api-solutions.sh.agoralab.co/"
    #else
    private static let host = "http://api-solutions-dev.sh.agoralab.co/"
    #endif
    private static let mainPath = "ent/v1/"
    
    static var userRegister: String {
        return URLGroup.host + URLGroup.mainPath + "user"
    }
    
    static var appVersion: String {
        return URLGroup.host + URLGroup.mainPath + "app/version"
    }
    
    static var userLogin: String {
        return URLGroup.host + URLGroup.mainPath + "user/login"
    }
    
    static var musicList: String {
        return URLGroup.host + URLGroup.mainPath + "musics"
    }
    
    static func userUpdateInfo(userId: String) -> String {
        return URLGroup.host + URLGroup.mainPath + "user/\(userId)"
    }
        
    static var roomPage: String {
        return URLGroup.host + URLGroup.mainPath + "room/page"
    }
    
    static var liveCreate: String {
        return URLGroup.host + URLGroup.mainPath + "room"
    }
    
    static func joinLive(roomId: String) -> String {
        return URLGroup.host + URLGroup.mainPath + "room/\(roomId)/entry"
    }
    
    static func leaveLive(roomId: String) -> String {
        return URLGroup.host + URLGroup.mainPath + "room/\(roomId)/exit"
    }
    
    static func audienceList(roomId: String) -> String {
        return URLGroup.host + URLGroup.mainPath + "room/\(roomId)/user/page"
    }
    
    static func liveSeatCommand(roomId: String) -> String {
        return URLGroup.host + URLGroup.mainPath + "room/\(roomId)/seat"
    }
    
    static func userCommand(userId: String, roomId: String) -> String {
        return URLGroup.host + URLGroup.mainPath + "room/\(roomId)/user/\(userId)"
    }
    
    static func receivedGift(roomId: String) -> String {
        return URLGroup.host + URLGroup.mainPath + "room/\(roomId)/gift"
    }
    
    static func pkLive(roomId: String) -> String {
        return URLGroup.host + URLGroup.mainPath + "room/\(roomId)/pk"
    }
}
