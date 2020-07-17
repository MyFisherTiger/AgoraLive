//
//  VirtualBroadcastersViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/5/29.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import AGEVideoLayout

class VirtualBroadcastersViewController: MaskViewController, LiveViewController {
    @IBOutlet weak var ownerView: IconTextView!
    @IBOutlet weak var videoContainer: AGEVideoContainer!
    @IBOutlet weak var inviteButton: UIButton!
    @IBOutlet weak var chatViewHeight: NSLayoutConstraint!
    
    private var ownerRenderView = UIView()
    private var broadcasterRenderView = UIView()
    
    // LiveViewController
    var tintColor = UIColor(red: 0,
                            green: 0,
                            blue: 0,
                            alpha: 0.08)
    
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
    var seatVM: LiveSeatVM!
    var virtualVM: VirtualVM!
    var monitor = NetworkMonitor(host: "www.apple.com")
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        broadcastingStatus()
        liveSeat()
        netMonitor()
        
        updateViews()
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
            guard let session = ALCenter.shared().liveSession,
                let role = session.role else {
                assert(false)
                return
            }
            
            let vc = segue.destination as! BottomToolsViewController
            vc.perspective = role.type
            vc.liveType = session.type
            self.bottomToolsVC = vc
        case "ChatViewController":
            let vc = segue.destination as! ChatViewController
            vc.cellColor = tintColor
            vc.contentColor = UIColor(hexString: "#333333")
            self.chatVC = vc
        default:
            break
        }
    }
}

extension VirtualBroadcastersViewController {
    func updateViews() {
        ownerView.frame = CGRect(x: 0,
                                 y: 0,
                                 width: UIScreen.main.bounds.width,
                                 height: UIScreen.main.bounds.height)
        
        videoContainer.backgroundColor = .white
        ownerRenderView.backgroundColor = .white
        broadcasterRenderView.backgroundColor = .white
        
        ownerView.backgroundColor = tintColor
        ownerView.offsetLeftX = -13
        ownerView.offsetRightX = 5
        ownerView.label.textColor = UIColor(hexString: "#333333")
        ownerView.label.font = UIFont.systemFont(ofSize: 11)
        
        personCountView.backgroundColor = tintColor
        personCountView.imageView.image = UIImage(named: "icon-mine-black")
        personCountView.label.textColor = UIColor(hexString: "#333333")
        
        let chatViewMaxHeight = UIScreen.main.bounds.height * 0.25
        if chatViewHeight.constant > chatViewMaxHeight {
            chatViewHeight.constant = chatViewMaxHeight
        }
    }
    
    // MARK: - Live Room
    func liveRoom(session: LiveSession) {
        guard let owner = session.owner,
            let role = session.role else {
            assert(false)
            return
        }
        
        let images = ALCenter.shared().centerProvideImagesHelper()
        
        switch owner {
        case .localUser(let user):
            ownerView.label.text = user.info.name
            ownerView.imageView.image = images.getHead(index: user.info.imageIndex)
        case .otherUser(let remote):
            ownerView.label.text = remote.info.name
            ownerView.imageView.image = images.getHead(index: remote.info.imageIndex)
        }
        
        if role.type != .audience {
            deviceVM.camera = .on
            deviceVM.mic = .on
        } else {
            deviceVM.camera = .off
            deviceVM.mic = .off
        }
        
        inviteButton.rx.tap.subscribe(onNext: { [unowned self] in
            guard let session = ALCenter.shared().liveSession,
                let owner = session.owner,
                let local = session.role else {
                    assert(false)
                    return
            }
            
            switch (self.virtualVM.broadcasting.value, owner) {
            case (.single, .localUser):
                self.presentInviteList()
            case (.multi, .localUser):
                self.ownerForceEndingBroadcasting()
            case (.multi, .otherUser):
                guard local.type == .broadcaster else {
                    return
                }
                self.presentEndingBroadcasting()
            default: break
            }
        }).disposed(by: bag)
    }
    
    func liveSeat() {
        seatVM.list.subscribe(onNext: { [unowned self] (list) in
            guard let session = ALCenter.shared().liveSession else {
                assert(false)
                return
            }
            
            if list.count == 1, let remote = list[0].user {
                self.virtualVM.broadcasting.accept(.multi([session.owner.user, remote]))
            } else {
                self.virtualVM.broadcasting.accept(.single(session.owner.user))
            }
        }).disposed(by: bag)
        
        // Owner
        seatVM.receivedAudienceRejectInvitation.subscribe(onNext: { [unowned self] (user) in
            var message: String
            if DeviceAssistant.Language.isChinese {
                message = user.info.name + NSLocalizedString("Invitation_Rejected_Description")
            } else {
                message = NSLocalizedString("Invitation_Rejected_Description") + " " + user.info.name
            }
            
            self.showAlert(NSLocalizedString("Invitation_Rejected"), message: message, handler: nil)
        }).disposed(by: bag)
        
        // Audience
        seatVM.receivedOwnerInvitation.subscribe(onNext: { [unowned self] (userSeat) in
            self.audienceRecievedBroadcastingInvitation(owner: userSeat.user)
        }).disposed(by: bag)
    }
    
    func broadcastingStatus() {
        virtualVM.broadcasting.subscribe(onNext: { [unowned self] (broadcasting) in
            guard let session = ALCenter.shared().liveSession,
                let owner = session.owner,
                var local = session.role else {
                    assert(false)
                    return
            }
            
            // Role update
            switch broadcasting {
            case .single:
                switch local.type {
                case .broadcaster:
                    session.broadcasterToAudience()
                    local = session.role!
                default:
                    break
                }
            case .multi(let users):
                for item in users where item.info.userId != owner.user.info.userId {
                    if item.info.userId == local.info.userId,
                        local.type == .audience {
                        session.audienceToBroadcaster()
                        local = session.role!
                    }
                }
            }
            
            // Button
            switch (self.virtualVM.broadcasting.value, owner) {
            case (.single, .localUser):
                self.inviteButton.isHidden = false
                self.inviteButton.setTitle(NSLocalizedString("Invite_Broadcasting"), for: .normal)
            case (.single, .otherUser):
                self.inviteButton.isHidden = true
            case (.multi, .localUser):
                self.inviteButton.isHidden = false
                self.inviteButton.setTitle(NSLocalizedString("Ending_Broadcasting"), for: .normal)
            case (.multi, .otherUser):
                if local.type == .broadcaster {
                    self.inviteButton.isHidden = false
                    self.inviteButton.setTitle(NSLocalizedString("Ending_Broadcasting"), for: .normal)
                } else {
                    self.inviteButton.isHidden = true
                }
            }
            
            // Owner RenderView
            switch owner {
            case .localUser(let user):
                self.playerVM.startRenderLocalVideoStream(id: user.agUId,
                                                          view: self.ownerRenderView)
            case .otherUser(let user):
                self.playerVM.startRenderRemoteVideoStream(id: user.agUId,
                                                           view: self.ownerRenderView)
            }
            
            // Broadcaster RenderView
            switch broadcasting {
            case .multi(let users):
                for item in users where item.info.userId != owner.user.info.userId {
                    if item.info.userId == local.info.userId {
                        self.playerVM.startRenderLocalVideoStream(id: local.agUId,
                                                                  view: self.broadcasterRenderView)
                    } else {
                        self.playerVM.startRenderRemoteVideoStream(id: item.agUId,
                                                                   view: self.broadcasterRenderView)
                    }
                }
            default:
                break
            }
            
            // Video Layout
            switch broadcasting {
            case .single:
                self.updateVideoLayout(onlyOwner: true)
            case .multi:
                self.updateVideoLayout(onlyOwner: false)
            }
        }).disposed(by: bag)
    }
    
    func updateVideoLayout(onlyOwner: Bool) {
        var layout: AGEVideoLayout
        
        if onlyOwner {
            layout = AGEVideoLayout(level: 0)
        } else {
            let width = UIScreen.main.bounds.width
            let height = width * 10 / 16
            
            layout = AGEVideoLayout(level: 0)
                .size(.constant(CGSize(width: width, height: height)))
                .itemSize(.scale(CGSize(width: 0.5, height: 1)))
                .startPoint(x: 0, y: 160 + UIScreen.main.heightOfSafeAreaTop)
        }
        
        videoContainer.listItem { [unowned self] (index) -> AGEView in
            if onlyOwner {
                return self.ownerRenderView
            } else {
                switch index.item {
                case 0: return self.ownerRenderView
                case 1: return self.broadcasterRenderView
                default: assert(false); return UIView()
                }
            }
        }
        
        videoContainer.listCount { (_) -> Int in
            return onlyOwner ? 1 : 2
        }
        
        videoContainer.setLayouts([layout], animated: true)
    }
    
    func showToast(_ text: String) {
        let view = TextToast(frame: CGRect(x: 0, y: 200, width: 0, height: 44), filletRadius: 8)
        view.text = text
        self.showToastView(view, duration: 1.0)
    }
}

extension VirtualBroadcastersViewController {
    func presentInviteList() {
        guard let session = ALCenter.shared().liveSession else {
            return
        }
        
        showMaskView { [unowned self] in
            self.hiddenMaskView()
            if let vc = self.userListVC {
                self.dismissChild(vc, animated: true)
            }
        }
        
        presentUserList(listType: .broadcasting)
        
        let roomId = session.roomId
        
        self.userListVC?.selectedInviteAudience.subscribe(onNext: { [unowned self] (user) in
            guard let session = ALCenter.shared().liveSession,
                let owner = session.owner,
                owner.isLocal else {
                return
            }
            
            self.hiddenMaskView()
            if let vc = self.userListVC {
                self.dismissChild(vc, animated: true)
                self.userListVC = nil
            }
            
            self.seatVM.localOwner(owner.user,
                                   command: .invite,
                                   on: LiveSeat(index: 1, state: .empty),
                                   with: user,
                                   of: roomId) {[unowned self] (_) in
                                    self.showAlert(message: NSLocalizedString("Invite_Broadcasting_Fail"))
            }
        }).disposed(by: bag)
    }
    
    func presentVirtualAppearance(close: Completion, confirm: Completion) {
        let vc = UIStoryboard.initViewController(of: "VirtualAppearanceViewController",
                                                 class: VirtualAppearanceViewController.self)
        
        self.present(vc, animated: true) { [unowned vc, unowned self] in
            vc.closeButton.rx.tap.subscribe(onNext: {
                if let close = close {
                    close()
                }
            }).disposed(by: self.bag)
            
            vc.confirmButton.rx.tap.subscribe(onNext: {
                if let confirm = confirm {
                    confirm()
                }
            }).disposed(by: self.bag)
        }
    }
    
    // Owner
    func ownerForceEndingBroadcasting() {
        self.showAlert(NSLocalizedString("Ending_Broadcasting"),
                       message: NSLocalizedString("Confirm_Ending_Broadcasting"),
                       action1: NSLocalizedString("Cancel"),
                       action2: NSLocalizedString("Confirm"),
                       handler1: { [unowned self] (_) in
                        self.hiddenMaskView()
        }) { [unowned self] (_) in
            self.hiddenMaskView()
            
            guard let session = ALCenter.shared().liveSession,
                let owner = session.owner,
                owner.isLocal else {
                return
            }
            let roomId = session.roomId
            self.seatVM.localOwner(owner.user,
                                   command: .forceToAudience,
                                   on: LiveSeat(index: 1, state: .close),
                                   of: roomId)
        }
    }
    
    // Broadcaster
    func presentEndingBroadcasting() {
        self.showAlert(NSLocalizedString("Ending_Broadcasting"),
                       message: NSLocalizedString("Confirm_Ending_Broadcasting"),
                       action1: NSLocalizedString("Cancel"),
                       action2: NSLocalizedString("Confirm"),
                       handler1: { [unowned self] (_) in
                        self.hiddenMaskView()
        }) { [unowned self] (_) in
            self.hiddenMaskView()
            
            guard let session = ALCenter.shared().liveSession,
                let role = session.role,
                role.type == .broadcaster else {
                return
            }
            
            let roomId = session.roomId
            self.seatVM.localBroadcaster(role,
                                         endBroadcastingOn: LiveSeat(index: 1, state: .empty),
                                         of: roomId)
        }
    }
    
    // Audience
    func audienceRecievedBroadcastingInvitation(owner: LiveRole) {
        self.showMaskView()
        
        self.showAlert(NSLocalizedString("Broadcasting_Invitation"),
                       message: NSLocalizedString("Confirm_Accept_Broadcasting_Invitation"),
                       action1: NSLocalizedString("Reject"),
                       action2: NSLocalizedString("Accept"),
                       handler1: { [unowned self] (_) in
                        self.hiddenMaskView()
                        
                        guard let session = ALCenter.shared().liveSession,
                            let role = session.role,
                            role.type == .audience else {
                            return
                        }
                        
                        self.seatVM.localAudience(role, rejectInvitingFrom: owner)
        }) { [unowned self] (_) in
            self.hiddenMaskView()
            
            guard let session = ALCenter.shared().liveSession,
                let role = session.role,
                role.type == .audience else {
                return
            }
            
            let roomId = session.roomId
            
            self.presentVirtualAppearance(close: { [unowned self] in
                self.seatVM.localAudience(role, rejectInvitingFrom: owner)
            }) { [unowned self] in
                self.seatVM.localAudience(role,
                                          acceptInvitingOn: 1,
                                          roomId: roomId,
                                          extra: ["virtualAvatar": self.enhancementVM.virtualAppearance.value.item])
            }
        }
    }
}
