//
//  CreateLiveViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/2/26.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import AgoraRtcKit
import RxSwift
import RxRelay

struct RandomName {
    static var list: [String] {
        var array: [String]
        
        if DeviceAssistant.Language.isChinese {
            array = ["陌上花开等你来", "天天爱你", "我爱你们",
                     "有人可以", "风情万种", "强势归来",
                     "哈哈哈", "聊聊", "美人舞江山",
                     "最美的回忆", "遇见你", "最长情的告白",
                     "全力以赴", "简单点", "早上好",
                     "春风十里不如你"]
        } else {
            array = ["Cheer", "Vibe", "Devine",
                     "Duo", "Ablaze", "Amaze",
                     "Harmony", "Verse", "Vigilant",
                     "Contender", "Vista", "Wander",
                     "Collections", "Moon", "Boho",
                     "Everest"]
        }
        return array
    }
}

class CreateLiveViewController: MaskViewController {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var nameBgView: UIView!
    
    @IBOutlet weak var switchCameraButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var beautyButton: UIButton!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var cameraPreview: UIView!
    @IBOutlet weak var randomButton: UIButton!
    
    private let bag = DisposeBag()
    
    private let deviceVM = MediaDeviceVM()
    private let playerVM = PlayerVM()
    private let enhancementVM = VideoEnhancementVM()
    
    private var localSettings = LocalLiveSettings(title: "")
    private var firstLayoutSubviews: Bool = false
    private var mediaSettingsNavi: UIViewController?
    private var beautyVC: UIViewController?
    
    var liveType: LiveType = .multiBroadcasters
    
    override func viewDidLoad() {
        super.viewDidLoad()
        nameTextField.delegate = self
        nameLabel.text = NSLocalizedString("Create_NameLabel")
        startButton.setTitle(NSLocalizedString("Create_Start"),
                             for: .normal)
        randomName()
        
        deviceVM.camera = .on
        deviceVM.cameraPosition = .front
        deviceVM.cameraResolution(.high)
        
        // workaround: make local preview render scale to 16:9
        let media = ALCenter.shared().centerProvideMediaHelper()
        media.setupVideo(resolution: CGSize.AgoraVideoDimension720x1280,
                         frameRate: .fps15,
                         bitRate: 1000)
        
        playerVM.startRenderLocalVideoStream(id: 0,
                                             view: self.cameraPreview)
        
        switch liveType {
        case .multiBroadcasters:
            var media = localSettings.media
            media.resolution = AgoraVideoDimension240x240
            media.frameRate = .fps15
            media.bitRate = 200
            localSettings.media = media
        case .singleBroadcaster:
            var media = localSettings.media
            media.resolution = CGSize.AgoraVideoDimension360x640
            media.frameRate = .fps15
            media.bitRate = 600
            localSettings.media = media
        case .pkBroadcasters:
            var media = localSettings.media
            media.resolution = CGSize.AgoraVideoDimension360x640
            media.frameRate = .fps15
            media.bitRate = 800
            localSettings.media = media
        case .virtualBroadcasters:
            var media = localSettings.media
            media.resolution = CGSize.AgoraVideoDimension720x1280
            media.frameRate = .fps15
            media.bitRate = 1000
            localSettings.media = media
            
            startButton.backgroundColor = UIColor(hexString: "#0088EB")
            settingsButton.isHidden = true
            beautyButton.isHidden = true
            switchCameraButton.isHidden = true
            backButton.setImage(UIImage(named: "icon-back-black"),
                                for: .normal)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showLimitToast()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let segueId = segue.identifier else {
            return
        }
        
        switch segueId {
        case "MultiBroadcastersViewController":
            guard let sender = sender,
                let info = sender as? LiveSession.JoinedInfo,
                let seatInfo = info.seatInfo else {
                    fatalError()
            }
            
            let vc = segue.destination as? MultiBroadcastersViewController
            vc?.audienceListVM.updateGiftListWithJson(list: info.giftAudience)
            vc?.seatVM = try! LiveSeatVM(list: seatInfo)
        case "SingleBroadcasterViewController":
            guard let sender = sender,
                let info = sender as? LiveSession.JoinedInfo else {
                    fatalError()
            }
            
            let vc = segue.destination as? SingleBroadcasterViewController
            vc?.audienceListVM.updateGiftListWithJson(list: info.giftAudience)
        case "PKBroadcastersViewController":
            guard let sender = sender,
                let info = sender as? LiveSession.JoinedInfo else {
                    fatalError()
            }
            
            var statistics: PKStatistics
            
            if let pkInfo = info.pkInfo {
                statistics = try! PKStatistics(dic: pkInfo)
            } else {
                statistics = PKStatistics(state: .none)
            }
            
            let vc = segue.destination as? PKBroadcastersViewController
            vc?.audienceListVM.updateGiftListWithJson(list: info.giftAudience)
            vc?.pkVM = PKVM(statistics: statistics)
        case "VirtualBroadcastersViewController":
            guard let sender = sender,
                let info = sender as? LiveSession.JoinedInfo,
                let seatInfo = info.seatInfo,
                let session = ALCenter.shared().liveSession else {
                    fatalError()
            }
            
            let vc = segue.destination as? VirtualBroadcastersViewController
            vc?.audienceListVM.updateGiftListWithJson(list: info.giftAudience)
            let seatVM = try! LiveSeatVM(list: seatInfo)
            vc?.seatVM = seatVM
            
            var broadcasting: VirtualVM.Broadcasting
            
            if seatVM.list.value.count == 1,
                let remote = seatVM.list.value[0].user {
                broadcasting = .multi([session.owner.user, remote])
            } else {
                broadcasting = .single(session.owner.user)
            }
            
            vc?.virtualVM = VirtualVM(broadcasting: BehaviorRelay(value: broadcasting))
        default:
            break
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.nameTextField.endEditing(true)
    }
    
    @IBAction func doRandomNamePressed(_ sender: UIButton) {
        randomName()
    }
    
    @IBAction func doCameraPressed(_ sender: UIButton) {
        deviceVM.switchCamera()
    }
    
    @IBAction func doClosePressed(_ sender: UIButton) {
        if liveType != .virtualBroadcasters {
            self.enhancementVM.reset()
            self.deviceVM.camera = .off
            self.navigationController?.dismiss(animated: true,
                                               completion: nil)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    @IBAction func doBeautyPressed(_ sender: UIButton) {
        self.showMaskView(color: UIColor.clear) { [unowned self] in
            self.hiddenMaskView()
            self.hiddenSubSettings()
        }
        presentBeautySettings()
    }
    
    @IBAction func doRoomSettingsPressed(_ sender: UIButton) {
        self.showMaskView(color: UIColor.clear) { [unowned self] in
            self.hiddenMaskView()
            self.hiddenSubSettings()
        }
        presentMediaSettings()
    }
    
    @IBAction func doStartPressed(_ sender: UIButton) {
        if let title = nameTextField.text, title.count > 0 {
            localSettings.title = title
        } else {
            self.showAlert("未输入房间名")
            return
        }
        
        self.startLivingWithLocalSettings(localSettings)
    }
    
    func hiddenSubSettings() {
        if let mediaSettingsNavi = mediaSettingsNavi {
            self.dismissChild(mediaSettingsNavi, animated: true)
            self.mediaSettingsNavi = nil
        }
        
        if let beautyVC = beautyVC {
            self.dismissChild(beautyVC, animated: true)
            self.beautyVC = nil
        }
    }
}

private extension CreateLiveViewController {
    func randomName() {
        guard let name = RandomName.list.randomElement() else {
            return
        }
        nameTextField.text = name
    }
    
    func showLimitToast() {
        let mainScreen = UIScreen.main
        let y = mainScreen.bounds.height - mainScreen.heightOfSafeAreaBottom - 38 - 15 - 150
        let view = TagImageTextToast(frame: CGRect(x: 15, y: y, width: 181, height: 44.0), filletRadius: 8)
        
        view.labelSize = CGSize(width: UIScreen.main.bounds.width - 30, height: 0)
        view.text = NSLocalizedString("Limit_Toast")
        view.tagImage = UIImage(named: "icon-yellow-caution")
        self.showToastView(view, duration: 5.0)
    }
    
    func presentMediaSettings() {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let identifier = "MediaSettingsNavigation"
        let mediaSettingsNavi = storyboard.instantiateViewController(withIdentifier: identifier)
        let mediaSettingsVC = mediaSettingsNavi.children.first! as! MediaSettingsViewController
        self.mediaSettingsNavi = mediaSettingsNavi
        
        mediaSettingsVC.settings = BehaviorRelay(value: localSettings.media)
        mediaSettingsVC.settings?.subscribe(onNext: { [unowned self] (newMedia) in
            var newSettings = self.localSettings
            newSettings.media = newMedia
            self.localSettings = newSettings
        }).disposed(by: bag)
        
        mediaSettingsVC.view.cornerRadius(5)
        
        let presenetedHeight: CGFloat = 239 + UIScreen.main.heightOfSafeAreaBottom
        let y = UIScreen.main.bounds.height - presenetedHeight
        let presentedFrame = CGRect(x: 0,
                                    y: y,
                                    width: UIScreen.main.bounds.width,
                                    height: UIScreen.main.bounds.height)
        self.presentChild(mediaSettingsNavi,
                          animated: true,
                          presentedFrame: presentedFrame)
    }
    
    func presentBeautySettings() {
        let beautyVC = UIStoryboard.initViewController(of: "BeautySettingsViewController",
                                                       class: BeautySettingsViewController.self)
        self.beautyVC = beautyVC
        
        beautyVC.view.cornerRadius(5)
        
        let presenetedHeight: CGFloat = 50 + (44 * 4) + UIScreen.main.heightOfSafeAreaBottom
        let y = UIScreen.main.bounds.height - presenetedHeight
        let presentedFrame = CGRect(x: 0,
                                    y: y,
                                    width: UIScreen.main.bounds.width,
                                    height: UIScreen.main.bounds.height)
        self.presentChild(beautyVC,
                          animated: true,
                          presentedFrame: presentedFrame)
        
        beautyVC.workSwitch.rx.value.subscribe(onNext: { [unowned self] (value) in
            self.beautyButton.isSelected = value
        }).disposed(by: bag)
    }
}

private extension CreateLiveViewController {
    func startLivingWithLocalSettings(_ settings: LocalLiveSettings) {
        self.showHUD()
        
        var extra: [String: Any]? = nil
        if liveType == .virtualBroadcasters {
            extra = ["virtualAvatar": enhancementVM.virtualAppearance.value.item]
        }
        
        LiveSession.create(roomSettings: settings,
                           type: liveType,
                           extra: extra,
                           success: { [unowned self] (session) in
                            self.joinLiving(session: session)
        }) { [unowned self] in
            self.hiddenHUD()
            self.showAlert(message:"start live fail")
        }
    }
    
    func joinLiving(session: LiveSession) {
        self.showHUD()
        
        let center = ALCenter.shared()
        center.liveSession = session
        session.join(success: { [unowned session, unowned self] (info: LiveSession.JoinedInfo) in
            self.hiddenHUD()
            
            switch session.type {
            case .multiBroadcasters:
                self.performSegue(withIdentifier: "MultiBroadcastersViewController", sender: info)
            case .singleBroadcaster:
                self.performSegue(withIdentifier: "SingleBroadcasterViewController", sender: info)
            case .pkBroadcasters:
                self.performSegue(withIdentifier: "PKBroadcastersViewController", sender: info)
            case .virtualBroadcasters:
                self.performSegue(withIdentifier: "VirtualBroadcastersViewController", sender: info)
            }
        }) { [unowned self] in
            self.hiddenHUD()
            self.showAlert(message:"join live fail")
        }
    }
}

extension CreateLiveViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if range.length == 1 && string.count == 0 {
            return true
        } else if let text = textField.text, text.count >= 25 {
            return false
        } else {
            return true
        }
    }
}
