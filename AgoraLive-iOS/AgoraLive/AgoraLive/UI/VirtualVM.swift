//
//  VirtualVM.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/6/1.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay

class VirtualVM: NSObject {
    enum Broadcasting {
        case single(LiveRole), multi([LiveRole])
    }
    
    var broadcasting: BehaviorRelay<Broadcasting>
    
    init(broadcasting: BehaviorRelay<Broadcasting>) {
        self.broadcasting = broadcasting
    }
}

private extension VirtualVM {
    
}
