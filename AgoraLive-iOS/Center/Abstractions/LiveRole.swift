//
//  LiveRole.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/3/19.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import AlamoClient

enum LiveRoleType: Int {
    case owner = 1, broadcaster, audience
}

struct UserStatus: OptionSet {
    let rawValue: Int
    
    static let camera = UserStatus(rawValue: 1)
    static let mic = UserStatus(rawValue: 1 << 1)
    static let chat = UserStatus(rawValue: 1 << 2)
    
    static func initWith(dic: StringAnyDic) throws -> UserStatus {
        var status = UserStatus(rawValue: 0)
        
        let enableMic = try dic.getBoolInfoValue(of: "enableAudio")
        let enableCamera = try dic.getBoolInfoValue(of: "enableVideo")
        let enableChat = try? dic.getBoolInfoValue(of: "enableChat")
        
        if enableMic {
            status.insert(.mic)
        }
        
        if enableCamera {
            status.insert(.camera)
        }
        
        if let chat = enableChat, chat {
            status.insert(.chat)
        } else if enableChat == nil {
            status.insert(.chat)
        }
        
        return status
    }
}

protocol LiveRole: UserInfoProtocol {
    var type: LiveRoleType {get set}
    var status: UserStatus {get set}
    var agoraUserId: Int {get set}
    
    mutating func updateLocal(status: UserStatus, of roomId: String, success: Completion, fail: ErrorCompletion)
}

extension LiveRole {
    mutating func updateLocal(status: UserStatus, of roomId: String, success: Completion = nil, fail: ErrorCompletion = nil) {
        self.status = status
        
        let url = URLGroup.userCommand(userId: self.info.userId, roomId: roomId)
        let parameters = ["enableAudio": status.contains(.mic) ? 1 : 0,
                          "enableVideo": status.contains(.camera) ? 1 : 0,
                          "enableChat": status.contains(.chat) ? 1 : 0]
        
        let client = ALCenter.shared().centerProvideRequestHelper()
        let event = RequestEvent(name: "local-update-status")
        
        let token = ["token": ALKeys.ALUserToken]
        let task = RequestTask(event: event,
                               type: .http(.post, url: url),
                               header: token,
                               parameters: parameters)
        let successCallback: DicEXCompletion = { (json) in
            try json.getCodeCheck()
            let isSuccess = try json.getBoolInfoValue(of: "data")
            if isSuccess, let callback = success {
                callback()
            } else if !isSuccess, let callback = fail {
                callback(ACError.fail("live-seat-command fail") )
            }
        }
        let response = ACResponse.json(successCallback)
        
        let fail: ACErrorRetryCompletion = { (error) in
            if let callback = fail {
                callback(error)
            }
            return .resign
        }
        
        client.request(task: task, success: response, failRetry: fail)
    }
}

// MARK: - Object
// MARK: - Audience
class LiveAudience: NSObject, LiveRole {
    var type: LiveRoleType = .audience
    var info: BasicUserInfo
    var status: UserStatus
    var agoraUserId: Int
    
    var giftRank: Int
    
    init(info: BasicUserInfo, agoraUserId: Int, giftRank: Int = 0) {
        self.info = info
        self.status = UserStatus(rawValue: 0)
        self.agoraUserId = agoraUserId
        self.giftRank = giftRank
    }
}

// MARK: - Broadcaster
class LiveBroadcaster: NSObject, LiveRole {
    var type: LiveRoleType = .broadcaster
    var info: BasicUserInfo
    var status: UserStatus
    var agoraUserId: Int
    
    var giftRank: Int
    
    init(info: BasicUserInfo, status: UserStatus, agoraUserId: Int, giftRank: Int = 0) {
        self.info = info
        self.status = status
        self.agoraUserId = agoraUserId
        self.giftRank = giftRank
    }
}

// MARK: - Owner
class LiveOwner: NSObject, LiveRole {
    var type: LiveRoleType = .owner
    var info: BasicUserInfo
    var status: UserStatus
    var agoraUserId: Int
    
    init(info: BasicUserInfo, status: UserStatus, agoraUserId: Int) {
        self.info = info
        self.status = status
        self.agoraUserId = agoraUserId
    }
}

// MARK: - Remote
class RemoteOwner: NSObject, LiveRole {
    var type: LiveRoleType = .owner
    var status: UserStatus
    var info: BasicUserInfo
    var agoraUserId: Int
    
    init(dic: StringAnyDic) throws {
        self.status = try UserStatus.initWith(dic: dic)
        self.info = try BasicUserInfo(dic: dic)
        self.agoraUserId = try dic.getIntValue(of: "uid")
    }
    
    init(info: BasicUserInfo, status: UserStatus, agoraUserId: Int) {
        self.info = info
        self.status = status
        self.agoraUserId = agoraUserId
    }
}

class RemoteBroadcaster: NSObject, LiveRole {
    var type: LiveRoleType = .broadcaster
    var status: UserStatus
    var info: BasicUserInfo
    var agoraUserId: Int
    
    init(dic: StringAnyDic) throws {
        self.status = try UserStatus.initWith(dic: dic)
        self.info = try BasicUserInfo(dic: dic)
        self.agoraUserId = try dic.getIntValue(of: "uid")
    }
    
    init(info: BasicUserInfo, status: UserStatus, agoraUserId: Int) {
        self.info = info
        self.status = status
        self.agoraUserId = agoraUserId
    }
}

class RemoteAudience: NSObject, LiveRole {
    var type: LiveRoleType = .audience
    var status: UserStatus
    var info: BasicUserInfo
    var agoraUserId: Int
    var giftRank: Int
    
    init(dic: StringAnyDic) throws {
        self.status = UserStatus(rawValue: 0)
        self.info = try BasicUserInfo(dic: dic)
        self.giftRank = 0
        
        if let uid = try? dic.getIntValue(of: "uid") {
            self.agoraUserId = uid
        } else {
            self.agoraUserId = -1
        }
    }
    
    init(info: BasicUserInfo, agoraUserId: Int) {
        self.info = info
        self.status = UserStatus(rawValue: 0)
        self.agoraUserId = agoraUserId
        self.giftRank = 0
    }
}
