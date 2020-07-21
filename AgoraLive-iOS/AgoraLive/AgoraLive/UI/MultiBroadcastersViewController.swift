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
        
        bottomTools(session: session, tintColor: tintColor)
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
        // Media
        seatVC?.userRender.subscribe(onNext: { [unowned self] (viewUser) in
            guard let session = ALCenter.shared().liveSession else {
                    assert(false)
                    return
            }
            
            let local = session.role
            if local.agUId == viewUser.1.agUId {
                self.playerVM.startRenderLocalVideoStream(id: viewUser.1.agUId,
                                                          view: viewUser.0)
            } else {
                self.playerVM.startRenderRemoteVideoStream(id: viewUser.1.agUId,
                                                           view: viewUser.0)
            }
        }).disposed(by: bag)
        
        seatVC?.userAudioSilence.subscribe(onNext: { [unowned self] (user) in
            guard let session = ALCenter.shared().liveSession,
                session.role.agUId == user.agUId else {
                    return
            }
            
            self.deviceVM.mic = user.permission.contains(.mic) ? .on : .off
        }).disposed(by: bag)
        
        // Live Seat List
        seatVM.list.subscribe(onNext: { [unowned self] (list) in
            guard let session = ALCenter.shared().liveSession else {
                assert(false)
                return
            }
            
            // Local user starts / stops broadcasting
            self.localUserRoleChangeWith(seatList: list)
            self.seatVC!.updateSeats(list, of: session)
        }).disposed(by: bag)
        
        // Live Seat Command
        seatVC?.commandFire.subscribe(onNext: { [unowned self] (seatCommand) in
            guard seatCommand.command != .none else {
                return
            }
            
            guard let session = ALCenter.shared().liveSession else {
                assert(false)
                return
            }
            
            switch seatCommand.command {
            // Owner
            case .invite:
                self.showMaskView(color: UIColor.clear) {
                    self.hiddenMaskView()
                    if let vc = self.userListVC {
                        self.dismissChild(vc, animated: true)
                        self.userListVC = nil
                    }
                }
                self.presentInviteList(seat: seatCommand.seat)
            case .close, .ban, .unban, .forceToAudience, .release:
                guard session.owner.value.isLocal,
                    session.role.type == .owner else {
                        assert(false)
                        return
                }
                let role = session.role
                let handler: ((UIAlertAction) -> Void)? = {[weak self] (_) in
                    self?.seatVM.localOwner(role,
                                            command: seatCommand.command,
                                            on: seatCommand.seat,
                                            of: roomId) { [weak self] (_) in
                                                self?.showAlert(NSLocalizedString("Seat_Command_Fail"))
                    }
                }
                
                let message = self.alertMessageOfSeatCommand(seatCommand.command,
                                                             with: seatCommand.seat.user?.info.name)
                
                self.showAlert(seatCommand.command.description,
                               message: message,
                               action1: NSLocalizedString("Cancel"),
                               action2: NSLocalizedString("Confirm"),
                               handler2: handler)
            // Broadcaster
            case .endBroadcasting:
                guard session.role.type == .broadcaster else {
                    assert(false)
                    return
                }
                let role = session.role
                self.showAlert(seatCommand.command.description,
                               message: NSLocalizedString("Confirm_End_Broadcasting"),
                               action1: NSLocalizedString("Cancel"),
                               action2: NSLocalizedString("Confirm")) { [unowned self] (_) in
                                self.seatVM.localBroadcaster(role,
                                                             endBroadcastingOn: seatCommand.seat,
                                                             of: roomId)
                }
            // Audience
            case .applyForBroadcasting:
                let handler: ((UIAlertAction) -> Void)? =  {[unowned self] (_) in
                    guard let session = ALCenter.shared().liveSession else {
                            assert(false)
                            return
                    }
                    
                    switch session.owner.value {
                    case .otherUser(let remote):
                        guard session.role.type == .audience else {
                            assert(false)
                            return
                        }
                        let role = session.role
                        self.seatVM.localAudience(role,
                                                  applyForBroadcastingTo: remote,
                                                  seat: seatCommand.seat) {[unowned self] (_) in
                                                    self.showAlert(NSLocalizedString("Apply_For_Broadcasting_Fail"))
                        }
                    case .localUser: assert(false); break
                    }
                }
                
                self.showAlert(NSLocalizedString("Apply_For_Broadcasting"),
                               action1: NSLocalizedString("Cancel"),
                               action2: NSLocalizedString("Confirm"),
                               handler2: handler)
            case .none:
                break
            }
        }).disposed(by: bag)
    }
    
    //MARK: - User List
    func presentInviteList(seat: LiveSeat) {
        guard let session = ALCenter.shared().liveSession else {
            assert(false)
            return
        }
        
        presentUserList(listType: .broadcasting)
        
        let roomId = session.roomId
        
        self.userListVC?.selectedInviteAudience.subscribe(onNext: { [unowned self] (user) in
            guard let session = ALCenter.shared().liveSession else {
                return
            }
            
            self.hiddenMaskView()
            if let vc = self.userListVC {
                self.dismissChild(vc, animated: true)
                self.userListVC = nil
            }
            
            let role = session.role
            guard role.type == .owner else {
                    assert(false)
                    return
            }
            
            self.seatVM.localOwner(role,
                                   command: .invite,
                                   on: seat,
                                   with: user,
                                   of: roomId) {[unowned self] (_) in
                                    self.showAlert(message: NSLocalizedString("Invite_Broadcasting_Fail"))
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
                self.playerVM.startRenderLocalVideoStream(id: user.agUId,
                                                     view: self.ownerRenderView.renderView)
                self.deviceVM.camera = .on
                self.deviceVM.mic = .on
            case .otherUser(let remote):
                let images = ALCenter.shared().centerProvideImagesHelper()
                self.ownerRenderView.imageView.image = images.getOrigin(index: remote.info.imageIndex)
                self.ownerRenderView.label.text  = remote.info.name
                self.playerVM.startRenderRemoteVideoStream(id: remote.agUId,
                                                 view: self.ownerRenderView.renderView)
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
            seatVM.receivedAudienceRejectInvitation.subscribe(onNext: { [unowned self] (user) in
                self.showAlert(message: user.info.name + NSLocalizedString("Reject"))
            }).disposed(by: bag)
            
            seatVM.receivedAudienceApplication.subscribe(onNext: { [unowned self] (userSeat) in
                self.showAlert(message: "\"\(userSeat.user.info.name)\" " + NSLocalizedString("Apply_For_Broadcasting"),
                               action1: NSLocalizedString("Reject"),
                               action2: NSLocalizedString("Confirm"), handler1: { (_) in
                                guard let session = ALCenter.shared().liveSession else {
                                    return
                                }
                                
                                let role = session.role
                                self.seatVM.localOwner(role, rejectBroadcastingAudience: userSeat.user.agUId)
                }) {[unowned self] (_) in
                    self.seatVM.localOwnerAcceptBroadcasting(audience: userSeat.user,
                                                             seatIndex: userSeat.seatIndex,
                                                             roomId: roomId)
                }
            }).disposed(by: bag)
        case .broadcaster:
            break
        case .audience:
            let audience = localRole
            
            seatVM.receivedOwnerInvitation.subscribe(onNext: {[unowned self] (userSeat) in
                self.showAlert(NSLocalizedString("Invite_Broadcasting"),
                               message: NSLocalizedString("Confirm_Accept_Broadcasting_Invitation"),
                               action1: NSLocalizedString("Reject"),
                               action2: NSLocalizedString("Confirm"),
                               handler1: {[unowned self] (_) in
                                
                                self.seatVM.localAudience(audience, rejectInvitingFrom: userSeat.user)
                }) {[unowned self] (_) in
                    self.seatVM.localAudience(audience, acceptInvitingOn: userSeat.seatIndex, roomId: roomId)
                }
            }).disposed(by: bag)
            
            seatVM.receivedOwnerRejectApplication.subscribe(onNext: {[unowned self] (userName) in
                self.showAlert(message: NSLocalizedString("Owner_Reject_Broadcasting_Application"))
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
    
    func alertMessageOfSeatCommand(_ command: SeatCommand, with userName: String?) -> String {
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
