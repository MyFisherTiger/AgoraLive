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
    var initatorRoom: RoomBrief
    var receiverRoom: RoomBrief
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
            let ownerObj = LiveOwner(info: info, permission: [.camera, .mic, .chat], agUId: agId)
            
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
    fileprivate var relayState = RelayState.none
    
    private(set) var receivedInvitation = PublishRelay<Battle>()
    private(set) var invitationIsByRejected = PublishRelay<Battle>()
    private(set) var InvitationIsByAccepted = PublishRelay<Battle>()
    private(set) var invitationTimeout = PublishRelay<Battle>()
    
    private(set) var state = BehaviorRelay(value: PKState.none)
    private(set) var event = PublishRelay<PKEvent>()
    private(set) var mediaRelayConfiguration: MediaRelayConfiguration?
    
    init(dic: StringAnyDic) throws {
        super.init()
        try self.parseJson(dic: dic)
        self.observe()
    }
    
    func sendInvitationTo(room: RoomBrief, fail: ErrorCompletion) {
        
    }
    
    func accpet(invitation: Battle) {
        
    }
    
    func reject(invitation: Battle) {
        
    }
}

private extension PKVM {
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
            
            guard let type = try? json.getEnum(of: "cmd", type: ALPeerMessage.AType.self) else {
                return
            }
            
            guard type == .pk else  {
                return
            }
            
            let data = try json.getDataObject()
            
            //
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
