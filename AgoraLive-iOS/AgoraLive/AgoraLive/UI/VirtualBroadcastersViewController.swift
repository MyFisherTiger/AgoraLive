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
    @IBOutlet weak var personCountView: RemindIconTextView!
    
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
    var multiHostsVM = MultiHostsVM()
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
        
        bottomTools(session: session)
        chatInput()
        musicList()
        broadcastingStatus()
        liveSeat()
        liveRole(session: session)
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
            guard let session = ALCenter.shared().liveSession else {
                assert(false)
                return
            }
            
            let vc = segue.destination as! BottomToolsViewController
            vc.perspective = session.role.type
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
        let images = ALCenter.shared().centerProvideImagesHelper()
        
        session.owner.subscribe(onNext: { [unowned self] (owner) in
            self.ownerView.label.text = owner.user.info.name
            self.ownerView.imageView.image = images.getHead(index: owner.user.info.imageIndex)
            
            self.playerVM.startRenderVideoStreamOf(user: owner.user,
                                                   on: self.ownerRenderView)
        }).disposed(by: bag)
        
        if session.role.type != .audience {
            deviceVM.camera = .on
            deviceVM.mic = .on
        } else {
            deviceVM.camera = .off
            deviceVM.mic = .off
        }
        
        inviteButton.rx.tap.subscribe(onNext: { [unowned self] in
            guard let session = ALCenter.shared().liveSession else {
                assert(false)
                return
            }
            
            switch (self.virtualVM.broadcasting.value, session.owner.value) {
            case (.single, .localUser):
                self.presentInvitationList()
            case (.multi, .localUser):
                self.forceBroadcasterToBeAudience()
            case (.multi, .otherUser):
                guard session.role.type == .broadcaster else {
                    return
                }
                self.presentEndBroadcasting()
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
                self.virtualVM.broadcasting.accept(.multi([session.owner.value.user, remote]))
            } else {
                self.virtualVM.broadcasting.accept(.single(session.owner.value.user))
            }
        }).disposed(by: bag)
    }
    
    func liveRole(session: LiveSession) {
        let roomId = session.roomId
        
        // owner
        multiHostsVM.invitationByRejected.subscribe(onNext: { (invitation) in
            if DeviceAssistant.Language.isChinese {
                self.showTextToast(text: invitation.receiver.info.name + "拒绝了这次邀请")
            } else {
                self.showTextToast(text: invitation.receiver.info.name + "rejected this invitation")
            }
        }).disposed(by: bag)
        
        // broadcaster
        multiHostsVM.receivedEndBroadcasting.subscribe(onNext: {
            if DeviceAssistant.Language.isChinese {
                self.showTextToast(text: "房主强迫你下麦")
            } else {
                self.showTextToast(text: "Owner forced you to becmoe a audience")
            }
        }).disposed(by: bag)
        
        // audience
        multiHostsVM.receivedInvitation.subscribe(onNext: { (invitation) in
            self.showAlert(NSLocalizedString("Broadcasting_Invitation"),
                           message: NSLocalizedString("Confirm_Accept_Broadcasting_Invitation"),
                           action1: NSLocalizedString("Reject"),
                           action2: NSLocalizedString("Accept"),
                           handler1: { [unowned self] (_) in
                            self.multiHostsVM.reject(invitation: invitation, of: roomId)
            }) { [unowned self] (_) in
                self.presentVirtualAppearance(close: { [unowned self] in
                    self.multiHostsVM.reject(invitation: invitation, of: roomId)
                }) { [unowned self] in
                    self.multiHostsVM.accept(invitation: invitation,
                                             of: roomId,
                                             extral: ["virtualAvatar": self.enhancementVM.virtualAppearance.value.item]) { (_) in
                                                self.showTextToast(text: "accept invitation fail")
                    }
                }
            }
        }).disposed(by: bag)
        
        // role update
        multiHostsVM.audienceBecameBroadcaster.subscribe(onNext: { [unowned self] (user) in
            if DeviceAssistant.Language.isChinese {
                let chat = Chat(name: user.info.name, text: " 上麦")
                self.chatVM.newMessages([chat])
            } else {
                let chat = Chat(name: user.info.name, text: " became a broadcaster")
                self.chatVM.newMessages([chat])
            }
        }).disposed(by: bag)
        
        multiHostsVM.broadcasterBecameAudience.subscribe(onNext: { [unowned self] (user) in
            if DeviceAssistant.Language.isChinese {
                let chat = Chat(name: user.info.name, text: " 下麦")
                self.chatVM.newMessages([chat])
            } else {
                let chat = Chat(name: user.info.name, text: " became a audience")
                self.chatVM.newMessages([chat])
            }
        }).disposed(by: bag)
    }
    
    func broadcastingStatus() {
        virtualVM.broadcasting.subscribe(onNext: { [unowned self] (broadcasting) in
            guard let session = ALCenter.shared().liveSession else {
                    assert(false)
                    return
            }
            
            let local = session.role
            
            // Button
            self.inviteButton.isHidden = local.type == .audience ? true : false
            
            switch local.type {
            case .owner:
                if broadcasting.isSingle  {
                    self.inviteButton.setTitle(NSLocalizedString("Invite_Broadcasting"), for: .normal)
                } else {
                    self.inviteButton.setTitle(NSLocalizedString("End_Broadcasting"), for: .normal)
                }
            case .broadcaster:
                self.inviteButton.setTitle(NSLocalizedString("End_Broadcasting"), for: .normal)
            case .audience:
                break
            }
            
            // Video Layout
            self.updateVideoLayout(onlyOwner: broadcasting.isSingle)
        }).disposed(by: bag)
    }
    
    func updateVideoLayout(onlyOwner: Bool, animated: Bool = true) {
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
}

extension VirtualBroadcastersViewController {
    func presentInvitationList() {
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
        
        self.userListVC?.selectedUser.subscribe(onNext: { [unowned self] (user) in
            guard let session = ALCenter.shared().liveSession,
                session.owner.value.isLocal else {
                return
            }
            
            self.hiddenMaskView()
            if let vc = self.userListVC {
                self.dismissChild(vc, animated: true)
                self.userListVC = nil
            }
            
            let invitation = MultiHostsVM.Invitation(seatIndex: 1,
                                                     initiator: session.role,
                                                     receiver: session.owner.value.user)
            
            self.multiHostsVM.send(invitation: invitation, of: roomId) { (_) in
                self.showTextToast(text: NSLocalizedString("Invite_Broadcasting_Fail"))
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
    func forceBroadcasterToBeAudience() {
        self.showAlert(NSLocalizedString("End_Broadcasting"),
                       message: NSLocalizedString("Confirm_End_Broadcasting"),
                       action1: NSLocalizedString("Cancel"),
                       action2: NSLocalizedString("Confirm"),
                       handler1: { [unowned self] (_) in
                        self.hiddenMaskView()
        }) { [unowned self] (_) in
            guard let session = ALCenter.shared().liveSession,
                session.owner.value.isLocal else {
                return
            }
            let roomId = session.roomId
            
            guard let user = self.seatVM.list.value.first?.user else {
                return
            }
            
            self.multiHostsVM.forceEndBroadcasting(user: user,
                                                   on: 1,
                                                   of: roomId) { (_) in
                                                    self.showTextToast(text: "force user end broadcasting")
            }
        }
    }
    
    // Broadcaster
    func presentEndBroadcasting() {
        self.showAlert(NSLocalizedString("End_Broadcasting"),
                       message: NSLocalizedString("Confirm_End_Broadcasting"),
                       action1: NSLocalizedString("Cancel"),
                       action2: NSLocalizedString("Confirm"),
                       handler1: { [unowned self] (_) in
                        self.hiddenMaskView()
        }) { [unowned self] (_) in
            self.hiddenMaskView()
            
            guard let session = ALCenter.shared().liveSession,
                session.role.type == .broadcaster else {
                return
            }
            let roomId = session.roomId
            self.multiHostsVM.endBroadcasting(seatIndex: 1,
                                              user: session.role,
                                              of: roomId)
        }
    }
}
