//
//  GoodsVM.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/7/28.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import AlamoClient

struct GoodsItem {
    var name: String
    var description: String
    var price: Float
    var id: String
    var isSale: Bool
    
    init(dic: StringAnyDic) throws {
        self.id = try dic.getStringValue(of: "productId")
        self.name = try dic.getStringValue(of: "productName")
        self.price = try dic.getFloatInfoValue(of: "price")
        self.isSale = try dic.getBoolInfoValue(of: "state")
        self.description = "description"
    }
}

class GoodsVM: RxObject {
    let list = BehaviorRelay(value: [GoodsItem]())
    let onShelfList = BehaviorRelay(value: [GoodsItem]())
    let offShelfList = BehaviorRelay(value: [GoodsItem]())
    
    let itemOnShelf = PublishRelay<GoodsItem>()
    let itemOffShelf = PublishRelay<GoodsItem>()
    
    let requestError = PublishRelay<String>()
    
    override init() {
        super.init()
        observe()
    }
    
//    func fake() {
//        var temp = [GoodsItem]()
//
//        for i in 0 ..< 8 {
//            let item = GoodsItem(name: "name\(i)",
//                          description: "description\(i)",
//                                price: Float(i),
//                                   id: i,
//                               isSale: (i % 2) == 0 ? true : false)
//            temp.append(item)
//        }
//
//        list.accept(temp)
//    }
    
    func itemOnShelf(_ item: GoodsItem, of roomId: String) {
        goods(item, onShelf: true, of: roomId)
    }
    
    func itemOffShelf(_ item: GoodsItem, of roomId: String) {
        goods(item, onShelf: false, of: roomId)
    }
    
    func refetchList(of roomId: String) {
        let client = ALCenter.shared().centerProvideRequestHelper()
        let task = RequestTask(event: RequestEvent(name: "goods-list"),
                               type: .http(.post, url: URLGroup.goodsList(roomId: roomId)),
                               timeout: .medium,
                               header: ["token": ALKeys.ALUserToken])
        
        client.request(task: task, success: ACResponse.json({ [unowned self] (json) in
            let data = try json.getListValue(of: "data")
            let list = try [GoodsItem](dicList: data)
            
            self.list.accept(list)
        })) { [unowned self] (error) -> RetryOptions in
            self.requestError.accept("fetch product list fail")
            return .resign
        }
    }
    
    func purchase(item: GoodsItem, count: Int, of roomId: String) {
        let client = ALCenter.shared().centerProvideRequestHelper()
        let task = RequestTask(event: RequestEvent(name: "goods-purchase"),
                               type: .http(.post, url: URLGroup.goodsPurchase(roomId: roomId)),
                               timeout: .medium,
                               header: ["token": ALKeys.ALUserToken],
                               parameters: ["productId": item.id, "count": count])
        client.request(task: task) { [unowned self] (error) -> RetryOptions in
            self.requestError.accept("purchase product fail")
            return .resign
        }
    }
    
    deinit {
        let rtm = ALCenter.shared().centerProvideRTMHelper()
        rtm.removeReceivedChannelMessage(observer: self)
    }
    
}
private extension GoodsVM {
    func goods(_ item: GoodsItem, onShelf: Bool, of roomId: String) {
        let client = ALCenter.shared().centerProvideRequestHelper()
        var name: String
        if onShelf {
            name = "goods-on-shelf"
        } else {
            name = "goods-off-shelf"
        }
        
        let task = RequestTask(event: RequestEvent(name: name),
                               type: .http(.post, url: URLGroup.goodsOnShelf(roomId: roomId, state: onShelf ? 1 : 0, goodsId: item.id)),
                               timeout: .medium,
                               header: ["token": ALKeys.ALUserToken])
        client.request(task: task) { [unowned self] (error) -> RetryOptions in
            var message: String
            if onShelf {
                message = "product on shelf fail"
            } else {
                message = "product off shelf fall"
            }
            self.requestError.accept(message)
            return .resign
        }
    }
    
    func observe() {
        let rtm = ALCenter.shared().centerProvideRTMHelper()
        
        rtm.addReceivedChannelMessage(observer: self) { [weak self] (json) in
            guard let strongSelf = self else {
                return
            }
            
            guard try json.getEnum(of: "cmd", type: ALChannelMessage.AType.self) == .goodsOnShelf else {
                return
            }
            
            let data = try json.getDataObject()
            let productId = try data.getStringValue(of: "productId")
            let state = try data.getIntValue(of: "state")
            let new = strongSelf.list.value
            
            let item = new.first(where: { (item) -> Bool in
                return item.id == productId
            })
            
            guard var tItem = item else {
                return
            }
            
            if state == 1 {
                tItem.isSale = true
                strongSelf.itemOnShelf.accept(tItem)
            } else {
                tItem.isSale = false
                strongSelf.itemOnShelf.accept(tItem)
            }
        }
        
        itemOnShelf.subscribe(onNext: { [unowned self] (item: GoodsItem) in
            var new = self.list.value
            let index = new.firstIndex { (goods) -> Bool in
                return goods.id == item.id
            }
            
            guard let tIndex = index else {
                return
            }
            new.remove(at: tIndex)
            new.insert(item, at: 0)
            self.list.accept(new)
        }).disposed(by: bag)
        
        itemOffShelf.subscribe(onNext: { [unowned self] (item: GoodsItem) in
            var new = self.list.value
            let index = new.firstIndex { (goods) -> Bool in
                return goods.id == item.id
            }
            
            guard let tIndex = index else {
                return
            }
            new.remove(at: tIndex)
            new.append(item)
            self.list.accept(new)
        }).disposed(by: bag)
        
        list.subscribe(onNext: { [unowned self] (list) in
            let onShelf = list.filter { (item) -> Bool in
                return item.isSale
            }

            self.onShelfList.accept(onShelf)

            let offShelf = list.filter { (item) -> Bool in
                return !item.isSale
            }

            self.offShelfList.accept(offShelf)
        }).disposed(by: bag)
    }
}

fileprivate extension Array where Element == GoodsItem {
    init(dicList: [StringAnyDic]) throws {
        var array = [GoodsItem]()
        for item in dicList {
            let user = try GoodsItem(dic: item)
            array.append(user)
        }
        self = array
    }
}
