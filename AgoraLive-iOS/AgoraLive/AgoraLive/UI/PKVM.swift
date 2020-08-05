//
//  PKVM.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/4/13.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import AlamoClient

struct Battle {
    var id: String
    var initatorRoom: Room
    var receiverRoom: Room
}

struct PKInfo {
    struct RemoteRoom {
        var roomId: String
        var channel: String
        var owner: LiveRole
        
        init(dic: StringAnyDic) throws {
            let roomId = try dic.getStringValue(of: "roomId")
            let channel = try dic.getStringValue(of: "channel")
            let owner = try dic.getDictionaryValue(of: "owner")
            
            let userId = try owner.getStringValue(of: "userId")
            let userName = try owner.getStringValue(of: "userName")
            let agId = try owner.getIntValue(of: "uid")
            
            let info = BasicUserInfo(userId: userId, name: userName)
            let ownerObj = LiveRoleItem(type: .owner, info: info, permission: [.camera, .mic, .chat], agUId: agId)
            
            self.roomId = roomId
            self.channel = channel
            self.owner = ownerObj
        }
    }
    
    var remoteRoom: RemoteRoom
    var startTime: Int
    var countDown: Int
    var localRank: Int
    var remoteRank: Int
}

enum PKResult: Int {
    case win, draw, lose
}

enum PKEvent {
    case start(MediaRelayConfiguration), end(PKResult), rankChanged(local: Int, remote: Int)
}

enum PKState {
    case none, inviting, isBeingInvited, duration(PKInfo)
    
    var isDuration: Bool {
        switch self {
        case .duration: return true
        default:        return false
        }
    }
    
    var pkInfo: PKInfo? {
        switch self {
        case .duration(let info): return info
        default:                  return nil
        }
    }
}

struct MediaRelayConfiguration {
    var currentId: Int
    var currentChannelName: String
    var cuurentChannelToken: String
    var myIdOnRemoteChannel: Int
    var myTokenOnRemoteChannel: String
    
    var remoteChannelName: String
    var remoteIdOnCurrentChannel: Int
    
    init(dic: StringAnyDic) throws {
        let local = try dic.getDictionaryValue(of: "local")
        let proxy = try dic.getDictionaryValue(of: "proxy")
        let remote = try dic.getDictionaryValue(of: "remote")
        
        self.currentId = try local.getIntValue(of: "uid")
        self.currentChannelName = try local.getStringValue(of: "channelName")
        self.cuurentChannelToken = try local.getStringValue(of: "token")
        
        self.myIdOnRemoteChannel = try proxy.getIntValue(of: "uid")
        self.myTokenOnRemoteChannel = try proxy.getStringValue(of: "token")
    
        self.remoteChannelName = try proxy.getStringValue(of: "channelName")
        self.remoteIdOnCurrentChannel = try remote.getIntValue(of: "uid")
    }
}

fileprivate enum RelayState {
    case none, duration
}

class PKVM: NSObject {
    private var room: Room
    fileprivate var relayState = RelayState.none
    private(set) var mediaRelayConfiguration: MediaRelayConfiguration?
    
    let requestError = PublishRelay<String>()
    
    let receivedInvitation = PublishRelay<Battle>()
    let invitationIsByRejected = PublishRelay<Battle>()
    let invitationIsByAccepted = PublishRelay<Battle>()
    let invitationTimeout = PublishRelay<Battle>()
    
    let state = BehaviorRelay(value: PKState.none)
    let event = PublishRelay<PKEvent>()
    
    init(room: Room, state: StringAnyDic) throws {
        self.room = room
        super.init()
        try self.parseJson(dic: state)
        self.observe()
    }
    
    func sendInvitationTo(room: Room) {
        request(type: 1, roomId: self.room.roomId, to: room.roomId) { [unowned self] (_) in
            self.requestError.accept("pk invitation fail")
        }
    }
    
    func accept(invitation: Battle) {
        request(type: 2, roomId: self.room.roomId, to: invitation.initatorRoom.roomId) { [unowned self] (_) in
            self.requestError.accept("pk accept fail")
        }
    }
    
    func reject(invitation: Battle) {
        request(type: 3, roomId: room.roomId, to: invitation.initatorRoom.roomId) { [unowned self] (_) in
            self.requestError.accept("pk reject fail")
        }
    }
    
    deinit {
        let rtm = ALCenter.shared().centerProvideRTMHelper()
        rtm.removeReceivedChannelMessage(observer: self)
    }
}

private extension PKVM {
    func request(type: Int, roomId: String, to destinationRoomId: String, success: DicEXCompletion = nil, fail: ErrorCompletion) {
        let client = ALCenter.shared().centerProvideRequestHelper()
        let task = RequestTask(event: RequestEvent(name: "pk-action: \(type)"),
                               type: .http(.post, url: URLGroup.pkLiveBattle(roomId: roomId)),
                               timeout: .medium,
                               header: ["token": ALKeys.ALUserToken],
                               parameters: ["roomId": destinationRoomId, "type": type])
        client.request(task: task, success: ACResponse.json({ (json) in
            if let success = success {
                try success(json)
            }
        })) { (error) -> RetryOptions in
            if let fail = fail {
                fail(error)
            }
            return .resign
        }
    }
    
    func observe() {
        let rtm = ALCenter.shared().centerProvideRTMHelper()
        
        rtm.addReceivedChannelMessage(observer: self) { [weak self] (json) in
            guard let strongSelf = self else {
                return
            }
            
            guard let cmd = try? json.getEnum(of: "cmd", type: ALChannelMessage.AType.self) else {
                return
            }
            
            guard cmd == .pkEvent else  {
                return
            }
            
            let data = try json.getDataObject()
            try strongSelf.parseJson(dic: data)
        }
        
        rtm.addReceivedPeerMessage(observer: self) { [weak self] (json) in
            guard let strongSelf = self else {
                return
            }
            
            guard let cmd = try? json.getEnum(of: "cmd", type: ALPeerMessage.AType.self) else {
                return
            }
            
            guard cmd == .pk else  {
                return
            }
            
            let data = try json.getDataObject()
            let type = try data.getIntValue(of: "type")
            let room = try data.getDictionaryValue(of: "fromRoom")
            let remoteRoom = try Room(dic: room)
            
            // 1.邀请pk 2接受pk 3拒绝pk 4超时
            switch type {
                //
            case 1:
                let battle = Battle(id: "", initatorRoom: remoteRoom, receiverRoom: strongSelf.room)
                strongSelf.receivedInvitation.accept(battle)
            case 2:
                let battle = Battle(id: "", initatorRoom: strongSelf.room, receiverRoom: remoteRoom)
                strongSelf.invitationIsByAccepted.accept(battle)
            case 3:
                let battle = Battle(id: "", initatorRoom: strongSelf.room, receiverRoom: remoteRoom)
                strongSelf.invitationIsByRejected.accept(battle)
            case 4:
//                let battle = Battle(id: "", initatorRoom: strongSelf.room, receiverRoom: remoteRoom)
                break
            default:
                break
            }
        }
    }
    
    func parseJson(dic: StringAnyDic) throws {
        guard let session = ALCenter.shared().liveSession else {
            return
        }
        
        let owner = session.owner
        
        // Event
        if let eventInt = try? dic.getIntValue(of: "event") {
            var event: PKEvent
            
            switch eventInt {
            case 0:
                let result = try dic.getEnum(of: "result", type: PKResult.self)
                event = .end(result)
                guard owner.value.isLocal else {
                    return
                }
                stopRelayingMediaStream()
            case 1:
                let relayConfig = try dic.getDictionaryValue(of: "relayConfig")
                let configuration = try MediaRelayConfiguration(dic: relayConfig)
                event = .start(configuration)
                self.mediaRelayConfiguration = configuration
                guard owner.value.isLocal else {
                    return
                }
                startRelayingMediaStream(configuration)
            case 2:
                let local = try dic.getIntValue(of: "remoteRank")
                let remote = try dic.getIntValue(of: "localRoomRank")
                event = .rankChanged(local: local, remote: remote)
            default:
                assert(false)
                return
            }
            
            self.event.accept(event)
        } else if let relayConfig = try? dic.getDictionaryValue(of: "relayConfig")  {
            let info = try MediaRelayConfiguration(dic: relayConfig)
            startRelayingMediaStream(info)
        }
        
        // State
        let stateInt = try dic.getIntValue(of: "state")
        var state: PKState
        
        switch stateInt {
        case 0:
            state = .none
        case 1:
            state = .inviting
        case 2:
            state = .isBeingInvited
        case 3:
            let room = try PKInfo.RemoteRoom(dic: dic)
            let startTime = try dic.getIntValue(of: "startTime")
            let countDown = try dic.getIntValue(of: "countDown")
            let localRank = try dic.getIntValue(of: "localRank")
            let remoteRank = try dic.getIntValue(of: "localRoomRank")
            let info = PKInfo(remoteRoom: room,
                              startTime: startTime,
                              countDown: countDown,
                              localRank: localRank,
                              remoteRank: remoteRank)
            state = .duration(info)
        default:
            assert(false)
            return
        }
        
        self.state.accept(state)
    }
}

private extension PKVM {
    func startRelayingMediaStream(_ info: MediaRelayConfiguration) {
        let media = ALCenter.shared().centerProvideMediaHelper()
        
        let currentToken = info.cuurentChannelToken
        let currentChannel = info.currentChannelName
        let otherChannel = info.remoteChannelName
        let otherToken = info.myTokenOnRemoteChannel
        let otherUid = info.myIdOnRemoteChannel
        media.startRelayingMediaStreamOf(currentChannel: currentChannel,
                                         currentSourceToken: currentToken,
                                         to: otherChannel,
                                         with: otherToken,
                                         otherChannelUid: UInt(otherUid))
    }
    
    func stopRelayingMediaStream() {
        let media = ALCenter.shared().centerProvideMediaHelper()
        media.stopRelayingMediaStream()
    }
}
