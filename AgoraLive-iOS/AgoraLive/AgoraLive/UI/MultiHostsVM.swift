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

class MultiHostsVM: RxObject {
    struct Invitation: TimestampModel {
        var seatIndex: Int
        var initiator: LiveRole
        var receiver: LiveRole
        var timestamp: TimeInterval
        
        init(seatIndex: Int, initiator: LiveRole, receiver: LiveRole) {
            self.seatIndex = seatIndex
            self.initiator = initiator
            self.receiver = receiver
            self.timestamp = NSDate().timeIntervalSince1970
        }
    }
    
    struct Application: TimestampModel {
        var seatIndex: Int
        var initiator: LiveRole
        var receiver: LiveRole
        var timestamp: TimeInterval
        
        init(seatIndex: Int, initiator: LiveRole, receiver: LiveRole) {
            self.seatIndex = seatIndex
            self.initiator = initiator
            self.receiver = receiver
            self.timestamp = NSDate().timeIntervalSince1970
        }
    }
    
    let invitationQueue = TimestampQueue(name: "multi-hosts-invitation")
    let applicationQueue = TimestampQueue(name: "multi-hosts-application")
    
    let invitingUserList = BehaviorRelay(value: [LiveRole]())
    let applyingUserList = BehaviorRelay(value: [LiveRole]())
     
    // Owner
    var invitationByRejected = PublishRelay<Invitation>()
    var invitationByAccepted = PublishRelay<Invitation>()
    var receivedApplication = PublishRelay<Application>()
    
    // Broadcaster
    var receivedEndBroadcasting = PublishRelay<()>()
    
    // Audience
    var receivedInvitation = PublishRelay<Invitation>()
    var applicationByRejected = PublishRelay<Application>()
    var applicationByAccepted = PublishRelay<Application>()
    
    //
    var audienceBecameBroadcaster = PublishRelay<LiveRole>()
    var broadcasterBecameAudience = PublishRelay<LiveRole>()
    
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
                success: { [weak self] (json) in
                    self?.invitationQueue.append(invitation)
                }, fail: fail)
    }
    
    func accept(application: Application, of roomId: String, fail: ErrorCompletion = nil) {
        request(seatIndex: application.seatIndex,
                type: 5,
                userId: "\(application.initiator.info.userId)",
                roomId: roomId,
                success: { [weak self] (json) in
                    self?.applicationQueue.remove(application)
                }, fail: fail)
                
    }
    
    func reject(application: Application, of roomId: String, fail: ErrorCompletion = nil) {
        request(seatIndex: application.seatIndex,
                type: 3,
                userId: "\(application.initiator.info.userId)",
                roomId: roomId,
                success: { [weak self] (json) in
                    self?.applicationQueue.remove(application)
                }, fail: fail)
    }
    
    func forceEndBroadcasting(user: LiveRole, on seatIndex: Int, of roomId: String, fail: ErrorCompletion = nil) {
        request(seatIndex: seatIndex,
                type: 7,
                userId: "\(user.info.userId)",
                roomId: roomId,
                fail: fail)
    }
}

// MARK: Broadcaster
extension MultiHostsVM {
    func endBroadcasting(seatIndex: Int, user: LiveRole, of roomId: String, fail: ErrorCompletion = nil) {
        request(seatIndex: seatIndex,
                type: 8,
                userId: "\(user.info.userId)",
                roomId: roomId,
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
        request(seatIndex: invitation.seatIndex,
                type: 6,
                userId: "\(invitation.initiator.info.userId)",
                roomId: roomId,
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
    // type: 1.房主邀请 2.观众申请 3.房主拒绝 4.观众拒绝 5.房主同意观众申请 6.观众接受房主邀请 7.房主让主播下麦 8.主播下麦
    func request(seatIndex: Int, type: Int, userId: String, roomId: String, success: DicEXCompletion = nil, fail: ErrorCompletion) {
        let client = ALCenter.shared().centerProvideRequestHelper()
        let task = RequestTask(event: RequestEvent(name: "multi-invitation-or-application-type: \(type)"),
                               type: .http(.post, url: URLGroup.multiInvitaionApplication(userId: userId, roomId: roomId)),
                               timeout: .medium,
                               header: ["token": ALKeys.ALUserToken],
                               parameters: ["no": seatIndex, "type": type])
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
            // Owner
            case  101: // receivedApplication:
                let index = try data.getIntValue(of: "coindex")
                let application = Application(seatIndex: index, initiator: role, receiver: local)
                strongSelf.receivedApplication.accept(application)
            case  104: // audience rejected invitation
                let invitation = Invitation(seatIndex: 0, initiator: local, receiver: role)
                strongSelf.invitationByRejected.accept(invitation)
            case  106: // audience accpeted invitation:
                let index = try data.getIntValue(of: "coindex")
                let invitation = Invitation(seatIndex: index, initiator: local, receiver: role)
                strongSelf.invitationByAccepted.accept(invitation)
            // Audience
            case  102: // receivedInvitation
                let index = try data.getIntValue(of: "coindex")
                let invitation = Invitation(seatIndex: index, initiator: role, receiver: local)
                strongSelf.receivedInvitation.accept(invitation)
            case  103: // applicationByRejected
                let application = Application(seatIndex: 0, initiator: local, receiver: role)
                strongSelf.applicationByRejected.accept(application)
            case  105: // applicationByAccepted:
                let index = try data.getIntValue(of: "coindex")
                let application = Application(seatIndex: index, initiator: local, receiver: role)
                strongSelf.applicationByAccepted.accept(application)
            default:
                assert(false)
                break
            }
        }
        
        rtm.addReceivedChannelMessage(observer: self) { [weak self] (json) in
            guard let cmd = try? json.getEnum(of: "cmd", type: ALChannelMessage.AType.self),
                let strongSelf = self else {
                return
            }
            
            // strongSelf.audienceBecameBroadcaster
        }
        
        // Owner
        invitationByRejected.subscribe(onNext: { [weak self] (invitaion) in
            self?.invitationQueue.remove(invitaion)
        }).disposed(by: bag)
        
        invitationByAccepted.subscribe(onNext: { [weak self] (invitaion) in
            self?.invitationQueue.remove(invitaion)
        }).disposed(by: bag)
        
        //
        invitationQueue.queueChanged.subscribe(onNext: { [unowned self] (list) in
            guard let tList = list as? [Invitation] else {
                return
            }
            
            let users = tList.map { (invitation) -> LiveRole in
                return invitation.receiver
            }
            
            self.invitingUserList.accept(users)
        }).disposed(by: bag)
        
        applicationQueue.queueChanged.subscribe(onNext: { [unowned self] (list) in
            guard let tList = list as? [Application] else {
                return
            }
            
            let users = tList.map { (invitation) -> LiveRole in
                return invitation.initiator
            }
            
            self.applyingUserList.accept(users)
        }).disposed(by: bag)
    }
}
