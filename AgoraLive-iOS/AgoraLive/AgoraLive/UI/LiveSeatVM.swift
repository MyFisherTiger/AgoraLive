//
//  LiveSeatVM.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/3/26.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import AlamoClient

enum SeatState: Int {
    case empty = 0, normal, close
}

struct SeatMessage {
    enum `Type`: Int {
        case invitationOfOwner = 1, applicationOfAudience, ownerRejectedApplication, audienceRejectedInvitation
    }
    
    var index: Int
    var type: `Type`
}

struct LiveSeat {
    var user: LiveBroadcaster?
    var index: Int // 1 ... 6
    var state: SeatState
    
    init(user: LiveBroadcaster? = nil, index: Int, state: SeatState) {
        self.user = user
        self.index = index
        self.state = state
    }
    
    init(dic: StringAnyDic) throws {
        let seatJson = try dic.getDictionaryValue(of: "seat")
        self.index = try seatJson.getIntValue(of: "no")
        self.state = try seatJson.getEnum(of: "state", type: SeatState.self)
        
        if self.state == .normal {
            let broadcaster = try dic.getDictionaryValue(of: "user")
            self.user = try LiveBroadcaster(dic: broadcaster)
        }
    }
}

class LiveSeatVM: NSObject {
    private(set) var list: BehaviorRelay<[LiveSeat]>
    
    init(list: [StringAnyDic]) throws {
        var tempList = [LiveSeat]()
        
        for item in list {
            let seat = try LiveSeat(dic: item)
            tempList.append(seat)
        }
        
        self.list = BehaviorRelay(value: tempList.sorted(by: {$0.index < $1.index}))
        
        super.init()
        observe()
    }
    
    deinit {
        let rtm = ALCenter.shared().centerProvideRTMHelper()
        rtm.removeReceivedChannelMessage(observer: self)
    }
    
    func update(seatState: SeatState, index: Int, of roomId: String, fail: ErrorCompletion) {
        tempUpdateSeat(index: index,
                       state: seatState.rawValue,
                       userId: "0",
                       of: roomId,
                       fail: fail)
    }
}

private extension LiveSeatVM {
    // state: 0空位 1正常 2封麦
    func tempUpdateSeat(index: Int, state: Int, userId: String, of roomId: String, fail: ErrorCompletion) {
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
        rtm.addReceivedChannelMessage(observer: self) { [weak self] (json) in
            guard let cmd = try? json.getEnum(of: "cmd", type: ALChannelMessage.AType.self),
                cmd == .seats,
                let strongSelf = self else {
                return
            }
            
            let list = try json.getListValue(of: "data")
            var tempList = [LiveSeat]()
            for item in list {
                let seat = try LiveSeat(dic: item)
                tempList.append(seat)
            }
            strongSelf.list.accept(tempList.sorted(by: {$0.index < $1.index}))
        }
    }
}
