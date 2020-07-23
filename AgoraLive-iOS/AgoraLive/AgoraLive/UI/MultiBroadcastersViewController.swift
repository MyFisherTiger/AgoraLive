//
//  MultiBroadcastersViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/3/23.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import MJRefresh

class MultiBroadcastersViewController: MaskViewController, LiveViewController {
    @IBOutlet weak var ownerRenderView: LabelShadowRender!
    @IBOutlet weak var roomLabel: UILabel!
    @IBOutlet weak var roomNameLabel: UILabel!
    
    private weak var seatVC: LiveSeatViewController?
    
    var seatVM: LiveSeatVM!
    var multiHostsVM = MultiHostsVM()
    
    // LiveViewController
    var tintColor = UIColor(red: 0,
                            green: 0,
                            blue: 0,
                            alpha: 0.4)
    
    var bag = DisposeBag()
    
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
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
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
        liveRole(session: session)
        audience()
        liveSeat(roomId: session.roomId)
        chatList()
        gift()
        
        bottomTools(session: session)
        chatInput()
        musicList()
        netMonitor()
        activeSpeaker()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let identifier = segue.identifier else {
            return
        }
        
        switch identifier {
        case "LiveSeatViewController":
            guard let type = ALCenter.shared().liveSession?.role.type else {
                assert(false)
                return
            }
            
            let vc = segue.destination as! LiveSeatViewController
            vc.perspective = type
            self.seatVC = vc
        case "GiftAudienceViewController":
            let vc = segue.destination as! GiftAudienceViewController
            self.giftAudienceVC = vc
        case "BottomToolsViewController":
            guard let type = ALCenter.shared().liveSession?.role.type else {
                assert(false)
                return
            }
            
            let vc = segue.destination as! BottomToolsViewController
            vc.perspective = type
            self.bottomToolsVC = vc
        case "ChatViewController":
            let vc = segue.destination as! ChatViewController
            vc.cellColor = tintColor
            self.chatVC = vc
        default:
            break
        }
    }
    
    func activeSpeaker() {
        playerVM.activeSpeaker.subscribe(onNext: { [weak self] (speaker) in
            guard let strongSelf = self,
                let session = ALCenter.shared().liveSession else {
                    return
            }
            
            switch (speaker, session.owner.value) {
            case (.local, .localUser):
                strongSelf.ownerRenderView.startSpeakerAnimating()
            case (.other(agoraUid: let uid), .otherUser(let user)):
                if uid == user.agUId {
                    strongSelf.ownerRenderView.startSpeakerAnimating()
                } else {
                    fallthrough
                }
            default:
                strongSelf.seatVC?.activeSpeaker(speaker)
            }
        }).disposed(by: bag)
    }
}

//MARK: - Specail MultiBroadcasters
extension MultiBroadcastersViewController {
    //MARK: - Live Seat
    func liveSeat(roomId: String) {
        guard let seatVC = self.seatVC else {
            assert(false)
            return
        }
        
        // Media
        seatVC.userRender.subscribe(onNext: { [unowned self] (viewUser) in
            self.playerVM.startRenderVideoStreamOf(user: viewUser.user, on: viewUser.view)
        }).disposed(by: bag)
        
        seatVC.userAudioSilence.subscribe(onNext: { [unowned self] (user) in
            guard let session = ALCenter.shared().liveSession,
                session.role.agUId == user.agUId else {
                    return
            }
            
            self.deviceVM.mic = user.permission.contains(.mic) ? .on : .off
        }).disposed(by: bag)
        
        // Live Seat List
        seatVM.list.bind(to: seatVC.seats).disposed(by: bag)
            
        // Live Seat Command
        seatVC.actionFire.subscribe(onNext: { [unowned self] (action) in
            guard let session = ALCenter.shared().liveSession else {
                return
            }
            
            switch action.command {
            // seat state
            case .release, .close:
                let handler: ((UIAlertAction) -> Void)? = { [unowned self] (_) in
                    self.seatVM.update(seatState: action.command == .release ? .normal : .close,
                                       index: action.seat.index,
                                       of: roomId) { [unowned self] (_) in
                                        self.showTextToast(text: "update seat fail")
                    }
                }
                
                let message = self.alertMessageOfSeatCommand(action.command,
                                                             with: action.seat.user?.info.name)
                
                self.showAlert(action.command.description,
                               message: message,
                               action1: NSLocalizedString("Cancel"),
                               action2: NSLocalizedString("Confirm"),
                               handler2: handler)
            // owner
            case .invitation:
                self.showMaskView(color: UIColor.clear) {
                    self.hiddenMaskView()
                    if let vc = self.userListVC {
                        self.dismissChild(vc, animated: true)
                        self.userListVC = nil
                    }
                }
                self.presentInviteList { (user) in
                    let invitation = MultiHostsVM.Invitation(seatIndex: action.seat.index,
                                                             initiator: session.role,
                                                             receiver: session.owner.value.user)
                    
                    self.multiHostsVM.send(invitation: invitation, of: roomId) { (_) in
                        self.showTextToast(text: NSLocalizedString("Invite_Broadcasting_Fail"))
                    }
                }
            case .ban, .unban, .forceToAudience:
                guard let user = action.seat.user else {
                    return
                }
                
                let handler: ((UIAlertAction) -> Void)? = { [unowned self] (_) in
                    guard let session = ALCenter.shared().liveSession else {
                        return
                    }
                    
                    if action.command == .ban {
                        session.muteAudio(user: action.seat.user!) { [unowned self] in
                            self.showTextToast(text: "mute user audio fail")
                        }
                    } else if action.command == .unban {
                        session.unmuteAudio(user: action.seat.user!) { [unowned self] in
                            self.showTextToast(text: "ummute user audio fail")
                        }
                    } else if action.command == .forceToAudience {
                        self.multiHostsVM.forceEndBroadcasting(user: user,
                                                               on: action.seat.index,
                                                               of: roomId) { (_) in
                                                                self.showTextToast(text: "force user end broadcasting")
                        }
                    }
                }
                
                let message = self.alertMessageOfSeatCommand(action.command,
                                                             with: action.seat.user?.info.name)
                
                self.showAlert(action.command.description,
                               message: message,
                               action1: NSLocalizedString("Cancel"),
                               action2: NSLocalizedString("Confirm"),
                               handler2: handler)
            // broadcster
            case .endBroadcasting:
                self.showAlert(action.command.description,
                               message: NSLocalizedString("Confirm_End_Broadcasting"),
                               action1: NSLocalizedString("Cancel"),
                               action2: NSLocalizedString("Confirm")) { [unowned self] (_) in
                                guard let user = action.seat.user,
                                    let session = ALCenter.shared().liveSession else {
                                        return
                                }
                                
                                self.multiHostsVM.endBroadcasting(seatIndex: action.seat.index, user: user, of: roomId)
                                session.broadcasterToAudience()
                }
            // audience
            case .application:
                let application = MultiHostsVM.Application(seatIndex: action.seat.index,
                                                           initiator: session.role,
                                                           receiver: session.owner.value.user)
                self.multiHostsVM.send(application: application, of: roomId) { (_) in
                    self.showTextToast(text: "send application fail")
                }
            }
        }).disposed(by: bag)
    }
    
    //MARK: - User List
    func presentInviteList(selected: ((LiveRole) -> Void)? = nil) {
        presentUserList(listType: .broadcasting)
        
        self.userListVC?.selectedUser.subscribe(onNext: { [unowned self] (user) in
            self.hiddenMaskView()
            if let vc = self.userListVC {
                self.dismissChild(vc, animated: true)
                self.userListVC = nil
            }
            
            if let selected = selected {
                selected(user)
            }
        }).disposed(by: bag)
    }
}

private extension MultiBroadcastersViewController {
    // MARK: - Live Room
    func liveRoom(session: LiveSession) {
        let owner = session.owner
        
        ownerRenderView.cornerRadius(5)
        ownerRenderView.layer.masksToBounds = true
        ownerRenderView.imageView.isHidden = true
        ownerRenderView.backgroundColor = tintColor
        
        owner.subscribe(onNext: { [unowned self] (owner) in
            switch owner {
            case .localUser(let user):
                let images = ALCenter.shared().centerProvideImagesHelper()
                
                self.ownerRenderView.imageView.image = images.getOrigin(index: user.info.imageIndex)
                self.ownerRenderView.label.text = user.info.name
                self.playerVM.startRenderVideoStreamOf(user: user,
                                                       on: self.ownerRenderView.renderView)
                
                self.deviceVM.camera = .on
                self.deviceVM.mic = .on
            case .otherUser(let remote):
                let images = ALCenter.shared().centerProvideImagesHelper()
                self.ownerRenderView.imageView.image = images.getOrigin(index: remote.info.imageIndex)
                self.ownerRenderView.label.text  = remote.info.name
                self.playerVM.startRenderVideoStreamOf(user: remote,
                                                       on: self.ownerRenderView.renderView)
                
                self.deviceVM.camera = .off
                self.deviceVM.mic = .off
            }
            
            self.ownerRenderView.imageView.isHidden = owner.user.permission.contains(.camera)
            self.ownerRenderView.audioSilenceTag.isHidden = owner.user.permission.contains(.mic)
        }).disposed(by: bag)
        
        self.roomLabel.text = NSLocalizedString("Live_Room") + ": "
        self.roomNameLabel.text = session.settings.title
    }
    
    func liveRole(session: LiveSession) {
        let localRole = session.role
        let roomId = session.roomId
        
        // Owner
        switch localRole.type {
        case .owner:
            multiHostsVM.receivedApplication.subscribe(onNext: { (application) in
                self.showAlert(message: "\"\(application.initiator.info.name)\" " + NSLocalizedString("Apply_For_Broadcasting"),
                               action1: NSLocalizedString("Reject"),
                               action2: NSLocalizedString("Confirm"), handler1: { (_) in
                                self.multiHostsVM.reject(application: application, of: roomId)
                }) {[unowned self] (_) in
                    self.multiHostsVM.accept(application: application, of: roomId)
                }
            }).disposed(by: bag)
            
            multiHostsVM.invitationByRejected.subscribe(onNext: { (invitation) in
                if DeviceAssistant.Language.isChinese {
                    self.showTextToast(text: invitation.receiver.info.name + "拒绝了这次邀请")
                } else {
                    self.showTextToast(text: invitation.receiver.info.name + "rejected this invitation")
                }
            }).disposed(by: bag)
        case .broadcaster:
            multiHostsVM.receivedEndBroadcasting.subscribe(onNext: {
                if DeviceAssistant.Language.isChinese {
                    self.showTextToast(text: "房主强迫你下麦")
                } else {
                    self.showTextToast(text: "Owner forced you to becmoe a audience")
                }
            }).disposed(by: bag)
            break
        case .audience:
            multiHostsVM.receivedInvitation.subscribe(onNext: { (invitation) in
                self.showAlert(NSLocalizedString("Invite_Broadcasting"),
                               message: NSLocalizedString("Confirm_Accept_Broadcasting_Invitation"),
                               action1: NSLocalizedString("Reject"),
                               action2: NSLocalizedString("Confirm"),
                               handler1: {[unowned self] (_) in
                                self.multiHostsVM.reject(invitation: invitation, of: roomId)
                }) {[unowned self] (_) in
                    self.multiHostsVM.accept(invitation: invitation, of: roomId) { (_) in
                        self.showTextToast(text: "accept invitation fail")
                    }
                }
            }).disposed(by: bag)
            
            multiHostsVM.applicationByRejected.subscribe(onNext: { (application) in
                if DeviceAssistant.Language.isChinese {
                    self.showTextToast(text: "房间拒绝你的申请")
                } else {
                    self.showTextToast(text: "Owner rejected your application")
                }
            }).disposed(by: bag)
        }
    }
}

private extension MultiBroadcastersViewController {
    func localUserRoleChangeWith(seatList: [LiveSeat]) {
        guard let session = ALCenter.shared().liveSession else {
                assert(false)
                return
        }
        
        let role = session.role
        
        switch role.type {
        case .broadcaster:
            var isBroadcaster = false
            for seat in seatList where seat.state == .normal {
                guard let user = seat.user else {
                    assert(false)
                    return
                }
                
                if user.info.userId == role.info.userId {
                    isBroadcaster = true
                    break
                }
            }
            
            guard !isBroadcaster else {
                return
            }
            
            self.chatVM.sendMessage(NSLocalizedString("Stopped_Hosting"), local: role.info)
            let role = session.broadcasterToAudience()
            self.seatVC?.perspective = role.type
        case .audience:
            var isBroadcaster = false
            for seat in seatList where seat.state == .normal {
                guard let user = seat.user else {
                    assert(false)
                    return
                }
                
                if user.info.userId == role.info.userId {
                    isBroadcaster = true
                    break
                }
            }
            
            guard isBroadcaster else {
                return
            }
            
            self.chatVM.sendMessage(NSLocalizedString("Became_A_Host"), local: role.info)
            let role = session.audienceToBroadcaster()
            self.seatVC?.perspective = role.type
        case .owner:
            break
        }
    }
    
    func alertMessageOfSeatCommand(_ command: LiveSeatView.Command, with userName: String?) -> String {
        switch command {
        case .ban:
            if DeviceAssistant.Language.isChinese {
                return "禁止\"\(userName!)\"发言?"
            } else {
                return "mute \"\(userName!)\"?"
            }
        case .unban:
            if DeviceAssistant.Language.isChinese {
                return "解除\"\(userName!)\"禁言?"
            } else {
                return "unmute \"\(userName!)\"?"
            }
        case .forceToAudience:
            if DeviceAssistant.Language.isChinese {
                return "确定\"\(userName!)\"下麦?"
            } else {
                return "Stop \"\(userName!)\" hosting"
            }
        case .close:
            if DeviceAssistant.Language.isChinese {
                return "将关闭该麦位，如果该位置上有用户，将下麦该用户"
            } else {
                return "block this position"
            }
        case .release:
            return NSLocalizedString("Seat_Release_Description")
        default:
            assert(false)
            return ""
        }
    }
}
