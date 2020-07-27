//
//  ExtensionViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/4/1.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit

class ExtensionButton: UIButton {
    override func titleRect(forContentRect contentRect: CGRect) -> CGRect {
        let w: CGFloat = self.bounds.width
        let h: CGFloat = 17.0
        let x: CGFloat = 0
        let y: CGFloat = self.bounds.height - h
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        let wh: CGFloat = 42.0
        let x: CGFloat = (self.bounds.width - wh) * 0.5
        let y: CGFloat = 0
        return CGRect(x: x, y: y, width: wh, height: wh)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel?.textAlignment = .center
        titleLabel?.font = UIFont.systemFont(ofSize: 12)
        self.setTitleColor(UIColor(hexString: "#333333"), for: .normal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ExtensionViewController: UIViewController {
    @IBOutlet weak var titleLabel: UILabel!
    
    lazy var dataButton = ExtensionButton(frame: CGRect.zero)
    lazy var settingsButton = ExtensionButton(frame: CGRect.zero)
    lazy var switchCameraButton = ExtensionButton(frame: CGRect.zero)
    lazy var cameraButton = ExtensionButton(frame: CGRect.zero)
    lazy var micButton = ExtensionButton(frame: CGRect.zero)
    lazy var audioLoopButton = ExtensionButton(frame: CGRect.zero)
    
    var liveType: LiveType = .multiBroadcasters
    var perspective: LiveRoleType = .audience
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let color = UIColor(hexString: "#D8D8D8")
        let x: CGFloat = 15.0
        let width = UIScreen.main.bounds.width - (x * 2)
        titleLabel.text = NSLocalizedString("Tool")
        titleLabel.containUnderline(color,
                                    x: x,
                                    width: width)
        
        dataButton.setImage(UIImage(named: "icon-data"), for: .normal)
        dataButton.setTitle(NSLocalizedString("Real_Data"), for: .normal)
        view.addSubview(dataButton)
        
        switch perspective {
        case .owner, .broadcaster:
            if liveType != .virtualBroadcasters {
                settingsButton.setImage(UIImage(named: "icon-setting"), for: .normal)
                settingsButton.setTitle(NSLocalizedString("Live_Room_Settings"), for: .normal)
                view.addSubview(settingsButton)
                
                switchCameraButton.setImage(UIImage(named: "icon-rotate"), for: .normal)
                switchCameraButton.setTitle(NSLocalizedString("Switch_Camera"), for: .normal)
                view.addSubview(switchCameraButton)
                
                cameraButton.setImage(UIImage(named: "icon-video on"), for: .normal)
                cameraButton.setImage(UIImage(named: "icon-video off"), for: .selected)
                cameraButton.setTitle(NSLocalizedString("Camera"), for: .normal)
                cameraButton.setTitle(NSLocalizedString("Camera"), for: .selected)
                view.addSubview(cameraButton)
            }
            
            micButton.setImage(UIImage(named: "icon-speaker on"), for: .normal)
            micButton.setImage(UIImage(named: "icon-speaker off"), for: .selected)
            micButton.setTitle(NSLocalizedString("Mic"), for: .normal)
            micButton.setTitle(NSLocalizedString("Mic"), for: .selected)
            view.addSubview(micButton)
            
            audioLoopButton.setImage(UIImage(named: "icon-loop"), for: .normal)
            audioLoopButton.setImage(UIImage(named: "icon-loop-active"), for: .selected)
            audioLoopButton.setTitle(NSLocalizedString("Audio_Loop"), for: .normal)
            audioLoopButton.setTitle(NSLocalizedString("Audio_Loop"), for: .selected)
            view.addSubview(audioLoopButton)
        case .audience:
            break
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        switch perspective {
        case .owner, .broadcaster:
            func buttonsLayout(_ buttons: [UIButton], y: CGFloat) {
                let width: CGFloat = 63.0
                let height: CGFloat = 17.0 + 8.0 + 42.0
                let leftRightSpace: CGFloat = 25.0
                let betweenSpace: CGFloat = (UIScreen.main.bounds.width - (leftRightSpace * 2) - (width * 4)) / 3
                
                var lastButton: UIButton? = nil
                
                for button in buttons {
                    if lastButton == nil {
                        button.frame = CGRect(x: leftRightSpace,
                                              y: y,
                                              width: width,
                                              height: height)
                    } else {
                        button.frame = CGRect(x: lastButton!.frame.maxX + betweenSpace,
                                              y: y,
                                              width: width,
                                              height: height)
                    }
                    lastButton = button
                }
            }
            
            var y: CGFloat = self.titleLabel.frame.maxY + 20.0
            var buttons: [UIButton]
            
            if liveType != .virtualBroadcasters {
                buttons = [dataButton, settingsButton]
            } else {
                buttons = [dataButton]
            }
            
            buttonsLayout(buttons, y: y)
            
            y = dataButton.frame.maxY + 22.0
            
            if liveType != .virtualBroadcasters {
                buttons = [switchCameraButton, cameraButton, micButton, audioLoopButton]
            } else {
                buttons = [micButton, audioLoopButton]
            }
            
            buttonsLayout(buttons, y: y)
        case .audience:
            let width: CGFloat = 63.0
            let height: CGFloat = 17.0 + 8.0 + 42.0
            let y: CGFloat = self.titleLabel.frame.maxY + 20.0
            let x: CGFloat = (self.view.bounds.width - width) * 0.5
            self.dataButton.frame = CGRect(x: x,
                                           y: y,
                                           width: width,
                                           height: height)
        }
    }
}
