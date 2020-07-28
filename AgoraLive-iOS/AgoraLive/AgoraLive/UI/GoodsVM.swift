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

struct GoodsItem {
    var name: String
    var description: String
    var price: Float
    var id: Int
}

class GoodsVM: NSObject {
    var list = BehaviorRelay(value: [GoodsItem]())
    
    func itemOnShelves(_ item: GoodsItem) {
        
    }
    
    func itemOffShelves(_ item: GoodsItem) {
        
    }
    
    func refetchList(fail: ErrorCompletion) {
        
    }
    
    deinit {
        let rtm = ALCenter.shared().centerProvideRTMHelper()
        rtm.removeReceivedChannelMessage(observer: self)
    }
    
}
private extension GoodsVM {
    func observe() {
        let rtm = ALCenter.shared().centerProvideRTMHelper()
        
        rtm.addReceivedChannelMessage(observer: self) { [weak self] (json) in
            
        }
    }
}
