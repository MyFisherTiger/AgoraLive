//
//  SingleBroadcasterViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/4/13.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay

class SingleBroadcasterViewController: MaskViewController, LiveViewController {
    @IBOutlet weak var ownerView: IconTextView!
    @IBOutlet weak var renderView: UIView!
    
    // LiveViewController
    var tintColor = UIColor(red: 0,
                            green: 0,
                            blue: 0,
                            alpha: 0.6)
    
    var bag: DisposeBag = DisposeBag()
    
     // ViewController
    var userListVC: UserListViewController?
    var giftAudienceVC: GiftAudienceViewController?
    var chatVC: ChatViewController?
    var bottomToolsVC: BottomToolsViewController?
    var beautyVC: BeautySettingsViewController?
    var musicVC: MusicViewController?
    var dataVC: RealDataViewController?
    var extensionVC: ExtensionViewController?
    var mediaSettingsNavi: UIViewController?
    var giftVC: GiftViewController?
    var gifVC: GIFViewController?
    
    // View
    @IBOutlet weak var personCountView: IconTextView!
    
    internal lazy var chatInputView: ChatInputView = {
        let chatHeight: CGFloat = 50.0
        let frame = CGRect(x: 0,
                           y: UIScreen.main.bounds.height,
                           width: UIScreen.main.bounds.width,
                           height: chatHeight)
        let view = ChatInputView(frame: frame)
        view.isHidden = true
        return view
    }()
    
    // ViewModel
    var audienceListVM = LiveRoomAudienceList()
    var musicVM = MusicVM()
    var chatVM = ChatVM()
    var giftVM = GiftVM()
    var deviceVM = MediaDeviceVM()
    var playerVM = PlayerVM()
    var enhancementVM = VideoEnhancementVM()
    var monitor = NetworkMonitor(host: "www.apple.com")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let image = UIImage(named: "live-bg")
        self.view.layer.contents = image?.cgImage
        
        guard let session = ALCenter.shared().liveSession else {
            assert(false)
            return
        }
        
        liveSession(session)
        liveRoom(session: session)
        audience()
        chatList()
        gift()
        
        bottomTools(session: session, tintColor: tintColor)
        chatInput()
        musicList()
        netMonitor()
        superResolution(session: session)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
        
        switch identifier {
        case "GiftAudienceViewController":
            let vc = segue.destination as! GiftAudienceViewController
            self.giftAudienceVC = vc
        case "BottomToolsViewController":
            guard let session = ALCenter.shared().liveSession else {
                    assert(false)
                    return
            }
            let role = session.role
            let vc = segue.destination as! BottomToolsViewController
            vc.perspective = role.type
            vc.liveType = session.type
            self.bottomToolsVC = vc
        case "ChatViewController":
            let vc = segue.destination as! ChatViewController
            vc.cellColor = tintColor
            self.chatVC = vc
        default:
            break
        }
    }
}

extension SingleBroadcasterViewController {
    // MARK: - Live Room
    func liveRoom(session: LiveSession) {
        let owner = session.owner
        
        let images = ALCenter.shared().centerProvideImagesHelper()
        
        ownerView.offsetLeftX = -13
        ownerView.offsetRightX = 5
        ownerView.label.textColor = .white
        ownerView.label.font = UIFont.systemFont(ofSize: 11)
        
        session.owner.subscribe(onNext: { [unowned self] (owner) in
            switch owner {
            case .localUser(let user):
                self.ownerView.label.text = user.info.name
                self.ownerView.imageView.image = images.getHead(index: user.info.imageIndex)
                self.playerVM.startRenderLocalVideoStream(id: user.agUId,
                                                     view: self.renderView)
                self.deviceVM.camera = .on
                self.deviceVM.mic = .on
            case .otherUser(let remote):
                self.ownerView.label.text = remote.info.name
                self.ownerView.imageView.image = images.getHead(index: remote.info.imageIndex)
                self.playerVM.startRenderRemoteVideoStream(id: remote.agUId,
                                                 view: self.renderView)
                self.deviceVM.camera = .off
                self.deviceVM.mic = .off
            }
        }).disposed(by: bag)
    }
    
    func superResolution(session: LiveSession) {
        bottomToolsVC?.superRenderButton.rx.tap.subscribe(onNext: { [unowned self, unowned session] () in
            guard let vc = self.bottomToolsVC else {
                assert(false)
                return
            }
            
            vc.superRenderButton.isSelected.toggle()
            
            if vc.superRenderButton.isSelected {
                let view = TagImageTextToast(frame: CGRect(x: 0, y: 300, width: 181, height: 44.0), filletRadius: 8)
                view.text = NSLocalizedString("Super_Resolution_Enabled")
                view.tagImage = UIImage(named: "icon-done")
                self.showToastView(view, duration: 1.0)
            }
            
            switch session.owner.value {
            case .otherUser(let remote):
                let media = ALCenter.shared().centerProvideMediaHelper()
                media.player.renderRemoteVideoStream(id: remote.agUId,
                                                     superResolution: vc.superRenderButton.isSelected ? .on : .off)
            default:
                assert(false)
                break
            }
        }).disposed(by: bag)
    }
}
