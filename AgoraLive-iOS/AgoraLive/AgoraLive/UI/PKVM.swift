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

struct MediaRelayInfo {
    var currentChannelName: String
    var currentSourceToken: String
    var currentUidOfOpponent: Int
    var currentTokenOfOpponent: String
    
    var opponentChannelName: String
    var opponentUidOfCurrent: Int
    
    init(dic: StringAnyDic) throws {
        let local = try dic.getDictionaryValue(of: "local")
        let proxy = try dic.getDictionaryValue(of: "proxy")
        let remote = try dic.getDictionaryValue(of: "remote")
        
        self.currentChannelName = try local.getStringValue(of: "channelName")
        self.currentSourceToken = try local.getStringValue(of: "token")
        
        self.currentUidOfOpponent = try proxy.getIntValue(of: "uid")
        self.currentTokenOfOpponent = try proxy.getStringValue(of: "token")
    
        self.opponentChannelName = try proxy.getStringValue(of: "channelName")
        self.opponentUidOfCurrent = try remote.getIntValue(of: "uid")
    }
}

struct PKStatistics {
    enum State {
        enum Result: Int {
            case fail = 0, success, draw
        }
        
        case none, start, during, end(Result)
        
        var isDuring: Bool {
            switch self {
            case .start, .during: return true
            default:              return false
            }
        }
        
        var hasResult: Result? {
            switch self {
            case .end(let result): return result
            default:               return nil
            }
        }
        
        static func initWith(dic: StringAnyDic) throws -> State {
            let intState = try dic.getIntValue(of: "state")
            var state: State
            
            switch intState {
            case 0:
                state = .none
            case 1:
                state = .start
            case 2:
                state = .during
            case 3:
                let result = try dic.getEnum(of: "result", type: Result.self)
                state = .end(result)
            default:
                throw AGEError.fail("state invalid value: \(intState)")
            }
            
            return state
        }
    }
    
    var state: State
    var startTime: Int64
    var countDown: Int
    
    var currentGift: Int
    var opponentGift: Int
    var opponentRoomId: String
    
    var opponentOwner: LiveAudience?
    
    init(state: State = .none) {
        self.state = state
        self.startTime = -1
        self.countDown = 0
        
        self.currentGift = 0
        self.opponentRoomId = ""
        self.opponentGift = 0
    }
    
    init(dic: StringAnyDic) throws {
        let state = try State.initWith(dic: dic)
        self.state = state
        
        if self.state.isDuring {
            self.countDown = try dic.getIntValue(of: "countDown")
            self.startTime = try dic.getInt64Value(of: "pkStartTime")
            self.currentGift = try dic.getIntValue(of: "hostRoomRank")
            self.opponentRoomId = try dic.getStringValue(of: "pkRoomId")
            self.opponentGift = try dic.getIntValue(of: "pkRoomRank")
            
            let user = try dic.getDictionaryValue(of: "pkRoomOwner")
            self.opponentOwner = try LiveAudience(dic: user)
        } else {
            self.startTime = -1
            self.countDown = 0
            self.currentGift = 0
            self.opponentRoomId = ""
            self.opponentGift = 0
            self.opponentOwner = nil
        }
    }
}

class PKVM: NSObject {
    var receivedPKInvite = PublishRelay<RoomBrief>()
    var receivedPKReject = PublishRelay<RoomBrief>()
    
    var statistics: BehaviorRelay<PKStatistics>
    
    init(statistics: PKStatistics) {
        self.statistics = BehaviorRelay(value: statistics)
        super.init()
        self.observe()
    }
    
    func invitePK(localRoom: String, localUser: LiveRole, inviteRoom: RoomBrief, fail: ErrorCompletion = nil) {
        self.isInviteOrRejectPK(isInvite: true, localRoomId: localRoom, localUser: localUser, inviteRoom: inviteRoom, fail: fail)
    }
    
    func rejectPK(localRoom: String, localUser: LiveRole, inviteRoom: RoomBrief, fail: ErrorCompletion = nil) {
        self.isInviteOrRejectPK(isInvite: false, localRoomId: localRoom, localUser: localUser, inviteRoom: inviteRoom, fail: fail)
    }
    
    func startPK(action: AGESwitch, roomId: String, opponentRoomId: String, success: Completion = nil, fail: ErrorCompletion) {
        let client = ALCenter.shared().centerProvideRequestHelper()
        let parameters: StringAnyDic = ["roomId": action.boolValue ? opponentRoomId : ""]
        
        let url = URLGroup.pkLive(roomId: roomId)
        let event = RequestEvent(name: "pk-live-invite")
        let task = RequestTask(event: event,
                               type: .http(.post, url: url),
                               timeout: .low,
                               header: ["token": ALKeys.ALUserToken],
                               parameters: parameters)
        
        let successCallback: DicEXCompletion = { (json: ([String: Any])) in
            try json.getCodeCheck()
            let isSuccess = try json.getBoolInfoValue(of: "data")
         
            if let success = success, isSuccess {
                success()
            } else if let fail = fail, !isSuccess {
                let error = ACError.fail("pk live invite fail")
                fail(error)
            }
        }
        let response = ACResponse.json(successCallback)
        
        let retry: ACErrorRetryCompletion = { (error: Error) -> RetryOptions in
            if let fail = fail {
                fail(error)
            }
            return .resign
        }
        
        client.request(task: task, success: response, failRetry: retry)
    }
    
    deinit {
        let rtm = ALCenter.shared().centerProvideRTMHelper()
        rtm.removeReceivedPeerMessage(observer: self)
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
            guard cmd == .pkState else  {
                return
            }
            
            guard let session = ALCenter.shared().liveSession else {
                return
            }
            
            let owner = session.owner
            let data = try json.getDataObject()
            let statistics = try PKStatistics(dic: data)
            
            strongSelf.statistics.accept(statistics)
            
            switch statistics.state {
            case .none:
                guard owner.value.isLocal else {
                    return
                }
                
                strongSelf.stopRelayingMediaStream()
            case .during:
                guard owner.value.isLocal else {
                    return
                }
                
                if let config = try? data.getDictionaryValue(of: "relayConfig") {
                    let relayInfo = try MediaRelayInfo(dic: config)
                    strongSelf.startRelayingMediaStream(relayInfo)
                }
            case .start:
                guard owner.value.isLocal else {
                    return
                }
                
                if let config = try? data.getDictionaryValue(of: "relayConfig") {
                    let relayInfo = try MediaRelayInfo(dic: config)
                    strongSelf.startRelayingMediaStream(relayInfo)
                }
            case .end:
                guard owner.value.isLocal else {
                    return
                }
                
                strongSelf.stopRelayingMediaStream()
            }
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
            let cmd = try data.getIntValue(of: "operate")
            let agoraUid = try data.getIntValue(of: "agoraUid")
            let info = BasicUserInfo(userId: "", name: "")
            let owner = LiveOwner(info: info, permission: [.camera, .mic, .chat], agUId: agoraUid)
            
            switch cmd {
            case ALPeerMessage.Command.invitePK(fromRoom: "").rawValue:
                let fromRoom = try data.getStringValue(of: "pkRoomId")
                let room = RoomBrief(roomId: fromRoom, owner: owner)
                strongSelf.receivedPKInvite.accept(room)
            case ALPeerMessage.Command.rejectPK(fromRoom: "").rawValue:
                let fromRoom = try data.getStringValue(of: "pkRoomId")
                let room = RoomBrief(roomId: fromRoom, owner: owner)
                strongSelf.receivedPKReject.accept(room)
            default:
                break
            }
        }
    }
    
    func isInviteOrRejectPK(isInvite: Bool, localRoomId: String, localUser: LiveRole, inviteRoom: RoomBrief, fail: ErrorCompletion) {
        let rtm = ALCenter.shared().centerProvideRTMHelper()
        let message = ALPeerMessage(type: .pk,
                                    command: isInvite ? .invitePK(fromRoom: localRoomId) : .rejectPK(fromRoom: localRoomId),
                                    userName: localUser.info.name,
                                    userId: localUser.info.userId,
                                    agoraUid: localUser.agUId)
        
        do {
            let jsonString = try message.json().jsonString()
            try rtm.write(message: jsonString,
                          of: RequestEvent(name: isInvite ? "invite-pk" : "reject-pk"),
                          to: "\(inviteRoom.owner.agUId)",
                          fail: fail)
        } catch let error as ACError {
            if let fail = fail {
                fail(error)
            }
        } catch {
            if let fail = fail {
                fail(ACError.unknown())
            }
        }
    }
    
    func startRelayingMediaStream(_ info: MediaRelayInfo) {
        let media = ALCenter.shared().centerProvideMediaHelper()
        
        let currentToken = info.currentSourceToken
        let currentChannel = info.currentChannelName
        let otherChannel = info.opponentChannelName
        let otherToken = info.currentTokenOfOpponent
        let otherUid = info.currentUidOfOpponent
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
