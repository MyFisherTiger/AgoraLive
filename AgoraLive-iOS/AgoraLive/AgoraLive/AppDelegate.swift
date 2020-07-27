//
//  AppDelegate.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/2/10.
//  Copyright © 2020 CavanSu. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if #available(iOS 13.0, *) {
            self.window?.overrideUserInterfaceStyle = .light
        }
        
        let center = ALCenter.shared()
        center.appAssistant.checkMinVersion { [unowned center] in
            center.reinitAgoraServe()
            center.registerAndLogin()
        }
        return true
    }
}
