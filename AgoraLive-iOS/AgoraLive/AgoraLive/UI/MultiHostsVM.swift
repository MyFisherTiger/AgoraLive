//
//  MultiHostsVM.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/7/22.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import AlamoClient

class MultiHostsVM: NSObject {
    struct Invitation {
        var seatIndex: Int
        var initiator: LiveRole
        var receiver: LiveRole
    }
    
    struct Application {
        var seatIndex: Int
        var initiator: LiveRole
        var receiver: LiveRole
    }
    
    // Owner
    var invitationByRejected = PublishRelay<Invitation>()
    var invitationByAccepted = PublishRelay<Invitation>()
    var receivedApplication = PublishRelay<Application>()
    
    // Broadcaster
    var receivedEndBroadcasting = PublishRelay<()>()
    
    // Audience
    var receivedInvitation = PublishRelay<Invitation>()
    var applicationByRejected = PublishRelay<Application>()
    
    override init() {
        super.init()
        observe()
    }
    
    deinit {
        let rtm = ALCenter.shared().centerProvideRTMHelper()
        rtm.removeReceivedChannelMessage(observer: self)
    }
}

// MARK: Owner
extension MultiHostsVM {
    func send(invitation: Invitation, of roomId: String, fail: ErrorCompletion = nil) {
        request(seatIndex: invitation.seatIndex,
                type: 1,
                userId: "\(invitation.receiver.info.userId)",
                roomId: roomId,
                fail: fail)
    }
    
    func accept(application: Application, of roomId: String, fail: ErrorCompletion = nil) {
        tempUpdateSeat(index: application.seatIndex,
                       state: 1,
                       userId: application.initiator.info.userId,
                       of: roomId,
                       fail: fail)
    }
    
    func reject(application: Application, of roomId: String, fail: ErrorCompletion = nil) {
        request(seatIndex: application.seatIndex,
                type: 3,
                userId: "\(application.initiator.info.userId)",
                roomId: roomId,
                fail: fail)
    }
    
    func forceEndBroadcasting(user: LiveRole, on seatIndex: Int, of roomId: String, fail: ErrorCompletion = nil) {
        tempUpdateSeat(index: seatIndex,
                       state: 0,
                       userId: user.info.userId,
                       of: roomId,
                       fail: fail)
    }
}

// MARK: Broadcaster
extension MultiHostsVM {
    func endBroadcasting(seatIndex: Int, user: LiveRole, of roomId: String, fail: ErrorCompletion = nil) {
        tempUpdateSeat(index: seatIndex,
                       state: 0,
                       userId: user.info.userId,
                       of: roomId,
                       fail: fail)
    }
}

// MARK: Audience
extension MultiHostsVM {
    func send(application: Application, of roomId: String, fail: ErrorCompletion = nil) {
        request(seatIndex: application.seatIndex,
                type: 2,
                userId: "\(application.initiator.info.userId)",
                roomId: roomId,
                fail: fail)
    }
    
    func accept(invitation: Invitation, of roomId: String, extral: StringAnyDic? = nil, fail: ErrorCompletion = nil) {
        tempUpdateSeat(index: invitation.seatIndex,
                       state: 1,
                       userId: invitation.initiator.info.userId,
                       of: roomId,
                       fail: fail)
    }
    
    func reject(invitation: Invitation, of roomId: String, fail: ErrorCompletion = nil) {
        request(seatIndex: invitation.seatIndex,
                type: 4,
                userId: "\(invitation.initiator.info.userId)",
                roomId: roomId,
                fail: fail)
    }
}

private extension MultiHostsVM {
    // type: 1.主播邀请 2.观众申请 3.主播拒绝 4.观众拒绝
    func request(seatIndex: Int, type: Int, userId: String, roomId: String, fail: ErrorCompletion) {
        let client = ALCenter.shared().centerProvideRequestHelper()
        let task = RequestTask(event: RequestEvent(name: "multi-invitation-or-application-type: \(type)"),
                               type: .http(.post, url: URLGroup.multiInvitaionApplication(userId: userId, roomId: roomId)),
                               timeout: .medium,
                               header: ["token": ALKeys.ALUserToken],
                               parameters: ["no": seatIndex, "type": type])
        client.request(task: task) { (error) -> RetryOptions in
            if let fail = fail {
                fail(error)
            }
            return .resign
        }
    }
    
    // state: 0空位 1正常 2封麦
    func tempUpdateSeat(index: Int, state: Int, userId: String, of roomId: String, extral: StringAnyDic? = nil, fail: ErrorCompletion) {
        var parameters: StringAnyDic = ["no": index, "state": state, "userId": userId]
        if let extral = extral {
            for (key, value) in extral {
                parameters[key] = value
            }
        }
        
        let client = ALCenter.shared().centerProvideRequestHelper()
        let task = RequestTask(event: RequestEvent(name: "multi-seat-state \(state)"),
                               type: .http(.post, url: URLGroup.liveSeatCommand(roomId: roomId)),
                               timeout: .medium,
                               header: ["token": ALKeys.ALUserToken],
                               parameters: ["no": index, "state": state, "userId": userId])
        client.request(task: task) { (error) -> RetryOptions in
            if let fail = fail {
                fail(error)
            }
            return .resign
        }
    }
    
    func observe() {
        let rtm = ALCenter.shared().centerProvideRTMHelper()
        
        rtm.addReceivedPeerMessage(observer: self) { [weak self] (json) in
            guard let type = try? json.getEnum(of: "cmd", type: ALPeerMessage.AType.self),
                type == .broadcasting,
                let strongSelf = self else {
                return
            }
            
            let data = try json.getDataObject()
            let cmd = try data.getIntValue(of: "operate")
            let userName = try data.getStringValue(of: "account")
            let userId = try data.getStringValue(of: "userId")
            let agoraUid = try data.getIntValue(of: "agoraUid")
            
            let info = BasicUserInfo(userId: userId, name: userName)
            let role = LiveAudience(info: info, agUId: agoraUid)
            
            guard let local = ALCenter.shared().liveSession?.role else {
                return
            }
            
            switch cmd {
            case  101: //.applyForBroadcasting:
                let index = try data.getIntValue(of: "coindex")
                let application = Application(seatIndex: index, initiator: role, receiver: local)
                strongSelf.receivedApplication.accept(application)
            case  102: // .inviteBroadcasting:
                let index = try data.getIntValue(of: "coindex")
                let invitation = Invitation(seatIndex: index, initiator: role, receiver: local)
                strongSelf.receivedInvitation.accept(invitation)
            case  103: // .rejectBroadcasting:
                let application = Application(seatIndex: 0, initiator: local, receiver: role)
                strongSelf.applicationByRejected.accept(application)
            case  104: // .rejectInviteBroadcasting:
                let invitation = Invitation(seatIndex: 0, initiator: local, receiver: role)
                strongSelf.invitationByRejected.accept(invitation)
            case  105: // .acceptBroadcastingRequest:
                break
            case  106: // .acceptInvitingRequest:
                break
            case  201: // .invitePK:
                break
            case  202: // .rejectPK:
                break
            default:
                assert(false)
                break
            }
        }
    }
}
