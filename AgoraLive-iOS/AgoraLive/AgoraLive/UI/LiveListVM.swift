//
//  LiveListVM.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/2/21.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import AlamoClient

struct RoomBrief {
    var name: String
    var roomId: String
    var imageURL: String
    var personCount: Int
    var imageIndex: Int
    var owner: LiveOwner
    
    init(name: String = "", roomId: String, imageURL: String = "", personCount: Int = 0, owner: LiveOwner) {
        self.name = name
        self.roomId = roomId
        self.imageURL = imageURL
        self.personCount = personCount
        self.imageIndex = Int(Int64(self.roomId)! % 12)
        self.owner = owner
    }
    
    init(dic: StringAnyDic) throws {
        self.name = try dic.getStringValue(of: "roomName")
        self.roomId = try dic.getStringValue(of: "roomId")
        self.imageURL = try dic.getStringValue(of: "thumbnail")
        self.personCount = try dic.getIntValue(of: "currentUsers")
        let ownerAgoraUid = try dic.getIntValue(of: "ownerUid")
        
        let info = BasicUserInfo(userId: "", name: "")
        let owner = LiveOwner(info: info, permission: [.camera, .mic, .chat], agUId: ownerAgoraUid)
        self.owner = owner
        
        #warning("next version")
        self.imageIndex = Int(Int64(self.roomId)! % 12)
    }
}

fileprivate extension Array where Element == RoomBrief {
    init(dicList: [StringAnyDic]) throws {
        var array = [RoomBrief]()
        for item in dicList {
            let room = try RoomBrief(dic: item)
            array.append(room)
        }
        self = array
    }
}

class LiveListVM: NSObject {
    fileprivate var multiList = [RoomBrief]() {
        didSet {
            switch presentingType {
            case .multi:
                presentingList.accept(multiList)
            default:
                break
            }
        }
    }
    
    fileprivate var singleList = [RoomBrief](){
        didSet {
            switch presentingType {
            case .single:
                presentingList.accept(singleList)
            default:
                break
            }
        }
    }
    
    fileprivate var pkList = [RoomBrief]() {
        didSet {
            switch presentingType {
            case .pk:
                presentingList.accept(pkList)
            default:
                break
            }
        }
    }
    
    fileprivate var virtualList = [RoomBrief]() {
        didSet {
            switch presentingType {
            case .virtual:
                presentingList.accept(virtualList)
            default:
                break
            }
        }
    }
    
    fileprivate var eCommerceList = [RoomBrief]() {
        didSet {
            switch presentingType {
            case .eCommerce:
                presentingList.accept(eCommerceList)
            default:
                break
            }
        }
    }
    
    var presentingType = LiveType.multi {
        didSet {
            switch presentingType {
            case .multi:
                presentingList.accept(multiList)
            case .single:
                presentingList.accept(singleList)
            case .pk:
                presentingList.accept(pkList)
            case .virtual:
                presentingList.accept(virtualList)
            case .eCommerce:
                presentingList.accept(eCommerceList)
            }
        }
    }
    
    var presentingList = BehaviorRelay(value: [RoomBrief]())
}

extension LiveListVM {
    func fetch(count: Int = 10, success: Completion = nil, fail: Completion = nil) {
        guard let lastRoom = self.presentingList.value.last else {
            return
        }
        
        let client = ALCenter.shared().centerProvideRequestHelper()
        let requestListType = presentingType
        let parameters: StringAnyDic = ["nextId": lastRoom.roomId,
                                        "count": count,
                                        "type": requestListType.rawValue]
        
        let url = URLGroup.roomPage
        let event = RequestEvent(name: "room-page")
        let task = RequestTask(event: event,
                               type: .http(.get, url: url),
                               timeout: .low,
                               header: ["token": ALKeys.ALUserToken],
                               parameters: parameters)
        
        let successCallback: DicEXCompletion = { [weak self] (json: ([String: Any])) in
            guard let strongSelf = self else {
                return
            }
            
            let object = try json.getDataObject()
            let jsonList = try object.getValue(of: "list", type: [StringAnyDic].self)
            let list = try [RoomBrief](dicList: jsonList)
            
            switch requestListType {
            case .multi:
                strongSelf.multiList.append(contentsOf: list)
            case .single:
                strongSelf.singleList.append(contentsOf: list)
            case .pk:
                strongSelf.pkList.append(contentsOf: list)
            case .virtual:
                strongSelf.virtualList.append(contentsOf: list)
            case .eCommerce:
                strongSelf.eCommerceList.append(contentsOf: list)
            }
            
            if let success = success {
                success()
            }
        }
        let response = ACResponse.json(successCallback)
        
        let retry: ACErrorRetryCompletion = { (error: Error) -> RetryOptions in
            if let fail = fail {
                fail()
            }
            return .resign
        }
        
        client.request(task: task, success: response, failRetry: retry)
    }
    
    func refetch(success: Completion = nil, fail: Completion = nil) {
        let client = ALCenter.shared().centerProvideRequestHelper()
        let requestListType = presentingType
        let currentCount = presentingList.value.count == 0 ? 10 : presentingList.value.count
        let parameters: StringAnyDic = ["count": currentCount,
                                        "type": requestListType.rawValue]
        
        let url = URLGroup.roomPage
        let event = RequestEvent(name: "room-page-refetch")
        let task = RequestTask(event: event,
                               type: .http(.get, url: url),
                               timeout: .low,
                               header: ["token": ALKeys.ALUserToken],
                               parameters: parameters)
        
        let successCallback: DicEXCompletion = { [weak self] (json: ([String: Any])) in
            guard let strongSelf = self else {
                return
            }
            
            try json.getCodeCheck()
            let object = try json.getDataObject()
            let jsonList = try object.getValue(of: "list", type: [StringAnyDic].self)
            let list = try [RoomBrief](dicList: jsonList)
            
            switch requestListType {
            case .multi:
                strongSelf.multiList = list
            case .single:
                strongSelf.singleList = list
            case .pk:
                strongSelf.pkList = list
            case .virtual:
                strongSelf.virtualList = list
            case .eCommerce:
                strongSelf.eCommerceList = list
            }
            
            if let success = success {
                success()
            }
        }
        let response = ACResponse.json(successCallback)
        
        let retry: ACErrorRetryCompletion = { (error: Error) -> RetryOptions in
            if let fail = fail {
                fail()
            }
            return .resign
        }
        
        client.request(task: task, success: response, failRetry: retry)
    }
}
