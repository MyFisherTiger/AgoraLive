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

struct LivePermission: OptionSet {
    let rawValue: Int
    
    static let camera = LivePermission(rawValue: 1)
    static let mic = LivePermission(rawValue: 1 << 1)
    static let chat = LivePermission(rawValue: 1 << 2)
    
    static func permission(dic: StringAnyDic) throws -> LivePermission {
        var permission = LivePermission(rawValue: 0)
        
        let enableMic = try dic.getBoolInfoValue(of: "enableAudio")
        let enableCamera = try dic.getBoolInfoValue(of: "enableVideo")
        let enableChat = try? dic.getBoolInfoValue(of: "enableChat")
        
        if enableMic {
            permission.insert(.mic)
        }
        
        if enableCamera {
            permission.insert(.camera)
        }
        
        if let chat = enableChat, chat {
            permission.insert(.chat)
        } else if enableChat == nil {
            permission.insert(.chat)
        }
        
        return permission
    }
}

protocol LiveRole: UserInfoProtocol {
    var type: LiveRoleType {get set}
    var permission: LivePermission {get set}
    var agUId: Int {get set}
    
    mutating func updateLocal(permission: LivePermission, of roomId: String, success: Completion, fail: ErrorCompletion)
}

extension LiveRole {
    mutating func updateLocal(permission: LivePermission, of roomId: String, success: Completion = nil, fail: ErrorCompletion = nil) {
        self.permission = permission
        
        let url = URLGroup.userCommand(userId: self.info.userId, roomId: roomId)
        let parameters = ["enableAudio": permission.contains(.mic) ? 1 : 0,
                          "enableVideo": permission.contains(.camera) ? 1 : 0,
                          "enableChat": permission.contains(.chat) ? 1 : 0]
        
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
    var permission: LivePermission
    var agUId: Int
    
    var giftRank: Int
    
    init(info: BasicUserInfo, agUId: Int, giftRank: Int = 0) {
        self.info = info
        self.permission = LivePermission(rawValue: 0)
        self.agUId = agUId
        self.giftRank = giftRank
    }
}

// MARK: - Broadcaster
class LiveBroadcaster: NSObject, LiveRole {
    var type: LiveRoleType = .broadcaster
    var info: BasicUserInfo
    var permission: LivePermission
    var agUId: Int
    
    var giftRank: Int
    
    init(info: BasicUserInfo, permission: LivePermission, agUId: Int, giftRank: Int = 0) {
        self.info = info
        self.permission = permission
        self.agUId = agUId
        self.giftRank = giftRank
    }
}

// MARK: - Owner
class LiveOwner: NSObject, LiveRole {
    var type: LiveRoleType = .owner
    var info: BasicUserInfo
    var permission: LivePermission
    var agUId: Int
    
    init(info: BasicUserInfo, permission: LivePermission, agUId: Int) {
        self.info = info
        self.permission = permission
        self.agUId = agUId
    }
}

// MARK: - Remote
class RemoteOwner: NSObject, LiveRole {
    var type: LiveRoleType = .owner
    var permission: LivePermission
    var info: BasicUserInfo
    var agUId: Int
    
    init(dic: StringAnyDic) throws {
        self.permission = try LivePermission.permission(dic: dic)
        self.info = try BasicUserInfo(dic: dic)
        self.agUId = try dic.getIntValue(of: "uid")
    }
    
    init(info: BasicUserInfo, permission: LivePermission, agUId: Int) {
        self.info = info
        self.permission = permission
        self.agUId = agUId
    }
}

class RemoteBroadcaster: NSObject, LiveRole {
    var type: LiveRoleType = .broadcaster
    var permission: LivePermission
    var info: BasicUserInfo
    var agUId: Int
    
    init(dic: StringAnyDic) throws {
        self.permission = try LivePermission.permission(dic: dic)
        self.info = try BasicUserInfo(dic: dic)
        self.agUId = try dic.getIntValue(of: "uid")
    }
    
    init(info: BasicUserInfo, permission: LivePermission, agUId: Int) {
        self.info = info
        self.permission = permission
        self.agUId = agUId
    }
}

class RemoteAudience: NSObject, LiveRole {
    var type: LiveRoleType = .audience
    var permission: LivePermission
    var info: BasicUserInfo
    var agUId: Int
    var giftRank: Int
    
    init(dic: StringAnyDic) throws {
        self.permission = LivePermission(rawValue: 0)
        self.info = try BasicUserInfo(dic: dic)
        self.giftRank = 0
        
        if let uid = try? dic.getIntValue(of: "uid") {
            self.agUId = uid
        } else {
            self.agUId = -1
        }
    }
    
    init(info: BasicUserInfo, agUId: Int) {
        self.info = info
        self.permission = LivePermission(rawValue: 0)
        self.agUId = agUId
        self.giftRank = 0
    }
}
