//
//  VirtualAppearanceViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/5/27.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift


class VirtualAppearanceViewController: UIViewController, RxViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bigImageView: UIImageView!
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    
    private let enhancementVM = VideoEnhancementVM()
    
    var appearance: VirtualAppearance = .girl {
        didSet {
            guard appearance != .none else {
                enhancementVM.virtualAppearance(appearance)
                return
            }
            
            self.rightButton.isDeselected = (appearance == .girl ? false : true)
            self.leftButton.isDeselected = (appearance == .dog ? false : true)
            self.bigImageView.image = appearance.image
            
            enhancementVM.virtualAppearance(appearance)
        }
    }
    
    var bag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.text = NSLocalizedString("Virtual_Appearance_Select")
        confirmButton.setTitle(NSLocalizedString("Confirm"), for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        
        leftButton.imageView?.contentMode = .scaleAspectFit
        rightButton.imageView?.contentMode = .scaleAspectFit
        
        appearance = .girl
        
        leftButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.appearance = .dog
        }).disposed(by: bag)
        
        rightButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.appearance = .girl
        }).disposed(by: bag)
        
        confirmButton.rx.tap.subscribe(onNext: { [unowned self] in
            if let navigation = self.navigationController {
                let vc = UIStoryboard.initViewController(of: "CreateLiveViewController",
                                                         class: CreateLiveViewController.self)
                vc.liveType = .virtualBroadcasters
                navigation.pushViewController(vc, animated: true)
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        }).disposed(by: bag)
        
        closeButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.enhancementVM.reset()
            if let navigation = self.navigationController {
                navigation.dismiss(animated: true, completion: nil)
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        }).disposed(by: bag)
    }
}

fileprivate extension UIButton {
    var isDeselected: Bool {
        set {
            layer.borderColor = newValue ? UIColor.clear.cgColor : UIColor(hexString: "#008AF3").cgColor
            layer.borderWidth = newValue ? 0 : 1
            
            layer.shadowOpacity = newValue ? 0 : 0.3
            layer.shadowOffset = CGSize(width: 0, height: 0.5)
        }
        get {
            assert(false)
            return true
        }
    }
}
