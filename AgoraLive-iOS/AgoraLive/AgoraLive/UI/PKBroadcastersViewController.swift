//
//  PKBroadcastersViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/4/13.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay
import MJRefresh

class PKViewController: UIViewController {
    @IBOutlet weak var pkTimeView: IconTextView!
    @IBOutlet weak var leftRenderView: UIView!
    @IBOutlet weak var rightRenderView: UIView!
    @IBOutlet weak var intoOtherButton: UIButton!
    @IBOutlet weak var rightLabel: UILabel!
    @IBOutlet weak var giftBar: PKBar!
    
    private lazy var resultImageView: UIImageView = {
        let wh: CGFloat = 110
        let y: CGFloat = UIScreen.main.bounds.height
        let x: CGFloat = ((self.view.bounds.width - wh) * 0.5)
        let view = UIImageView(frame: CGRect.zero)
        view.contentMode = .scaleAspectFit
        view.frame = CGRect(x: x, y: y, width: wh, height: wh)
        return view
    }()
    
    private var timer: Timer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
        pkTimeView.offsetLeftX = -10
        pkTimeView.offsetRightX = 10
        pkTimeView.imageView.image = UIImage(named: "icon-time")
        pkTimeView.label.textColor = .white
        pkTimeView.label.font = UIFont.systemFont(ofSize: 11)
        pkTimeView.label.adjustsFontSizeToFitWidth = true
        pkTimeView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.6)
    }
    
    var countDown: Int = 0
    
    func startCountingDown() {
        guard timer == nil else {
            return
        }
        timer = Timer(timeInterval: 1.0,
                      target: self,
                      selector: #selector(countingDown),
                      userInfo: nil,
                      repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        timer.fire()
    }
    
    func stopCountingDown() {
        guard timer != nil else {
            return
        }
        timer.invalidate()
        timer = nil
    }
    
    @objc private func countingDown() {
        DispatchQueue.main.async { [unowned self] in
            if self.countDown >= 0 {
                let miniter = self.countDown / (60 * 1000)
                let second = (self.countDown / 1000) % 60
                let secondString = String(format: "%0.2d", second)
                self.pkTimeView.label.textAlignment = .left
                self.pkTimeView.label.text = "   \(NSLocalizedString("PK_Remaining")): \(miniter):\(secondString)"
                self.countDown -= 1000
            } else {
                self.stopCountingDown()
            }
        }
    }
    
    func showWinner(isLeft: Bool, completion: Completion = nil) {
        resultImageView.image = UIImage(named: "pic-Winner")
        
        let wh: CGFloat = 110
        let y: CGFloat = 127
        var x: CGFloat
        
        if isLeft {
            x = (leftRenderView.bounds.width - wh) * 0.5
        } else {
            x = leftRenderView.frame.maxX + (rightRenderView.bounds.width - wh) * 0.5
        }
        
        self.showResultImgeView(newFrame: CGRect(x: x, y: y, width: wh, height: wh),
                                completion: completion)
    }
    
    func showDraw(completion: Completion = nil) {
        resultImageView.image = UIImage(named: "pic-平局")
        
        let wh: CGFloat = 110
        let y: CGFloat = 127
        let x: CGFloat = ((self.view.bounds.width - wh) * 0.5)
        self.showResultImgeView(newFrame: CGRect(x: x, y: y, width: wh, height: wh),
                                completion: completion)
    }
    
    private func showResultImgeView(newFrame: CGRect, completion: Completion = nil) {
        self.view.insertSubview(resultImageView, at: self.view.subviews.count)
        resultImageView.isHidden = false
        
        UIView.animate(withDuration: TimeInterval.animation, animations: { [unowned self] in
            self.resultImageView.frame = newFrame
        }) { [unowned self] (finish) in
            guard finish else {
                return
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [unowned self] in
                self.resultImageView.isHidden = true
                if let completion = completion {
                    completion()
                }
            }
        }
    }
}

class PKBroadcastersViewController: MaskViewController, LiveViewController {
    @IBOutlet weak var ownerView: IconTextView!
    @IBOutlet weak var pkContainerView: UIView!
    @IBOutlet weak var renderView: UIView!
    @IBOutlet weak var pkButton: UIButton!
    @IBOutlet weak var chatViewHeight: NSLayoutConstraint!
    
    private var pkView: PKViewController?
    var pkVM: PKVM!
    
    // LiveViewController
    var tintColor = UIColor(red: 0,
                            green: 0,
                            blue: 0,
                            alpha: 0.6)
    
    var bag: DisposeBag = DisposeBag()
    
    // ViewController
    var giftAudienceVC: GiftAudienceViewController?
    var bottomToolsVC: BottomToolsViewController?
    var chatVC: ChatViewController?
    
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
    var userListVM: LiveUserListVM!
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
        
        bottomTools(session: session)
        chatInput()
        musicList()
        netMonitor()
        PK(session: session)
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
        case "PKViewController":
            let vc = segue.destination as! PKViewController
            self.pkView = vc
        default:
            break
        }
    }
}

extension PKBroadcastersViewController {
    // MARK: - Live Room
    func liveRoom(session: LiveSession) {
        let owner = session.owner
        
        ownerView.offsetLeftX = -14
        ownerView.offsetRightX = 5
        ownerView.label.textColor = .white
        ownerView.label.font = UIFont.systemFont(ofSize: 11)
        ownerView.backgroundColor = tintColor
        
        owner.subscribe(onNext: { [unowned self] (owner) in
            let images = ALCenter.shared().centerProvideImagesHelper()
            let user = owner.user
            self.ownerView.label.text = user.info.name
            self.ownerView.imageView.image = images.getHead(index: user.info.imageIndex)
            self.deviceVM.camera = owner.isLocal ? .on : .off
            self.deviceVM.mic = owner.isLocal ? .on : .off
            self.pkView?.intoOtherButton.isHidden = owner.isLocal
            self.pkButton.isHidden = !owner.isLocal
        }).disposed(by: bag)
        
        bottomToolsVC?.closeButton.rx.tap.subscribe(onNext: { [unowned self] () in
            if self.pkVM.state.value.isDuration {
                self.showAlert(NSLocalizedString("End_PK"),
                               message: NSLocalizedString("End_PK_Message"),
                               action1: NSLocalizedString("Cancel"),
                               action2: NSLocalizedString("End")) { [unowned self] (_) in
                                self.leave()
                                self.dimissSelf()
                }
            } else {
                self.showAlert(NSLocalizedString("Live_End"),
                               message: NSLocalizedString("Confirm_End_Live"),
                               action1: NSLocalizedString("Cancel"),
                               action2: NSLocalizedString("Confirm")) { [unowned self] (_) in
                                self.leave()
                                self.dimissSelf()
                }
            }
        }).disposed(by: bag)
    }
    
    func PK(session: LiveSession) {
        // View
        pkButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.presentInvitationRoomList()
        }).disposed(by: bag)
        
        pkView?.intoOtherButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.intoRemoteRoom()
        }).disposed(by: bag)
        
        // VM
        pkVM.event.subscribe(onNext: { [weak self] (event) in
            guard let strongSelf = self else {
                return
            }
            
            switch event {
            case .start:
                break
            case .end(let result):
                strongSelf.show(result: result)
            case .rankChanged(let local, let remote):
                strongSelf.pkView?.giftBar.leftValue = local
                strongSelf.pkView?.giftBar.rightValue = remote
            }
        }).disposed(by: bag)
        
        pkVM.state.subscribe(onNext: { [unowned self] (state) in
            guard let session = ALCenter.shared().liveSession else {
                return
            }
            
            self.renderView.isHidden = state.isDuration
            self.pkContainerView.isHidden = !state.isDuration
            
            let owner = session.owner.value
            self.pkButton.isHidden = !owner.isLocal
            
            switch state {
            case .duration(let info):
                guard let leftRender = self.pkView?.leftRenderView,
                    let rightRender = self.pkView?.rightRenderView else {
                    return
                }
                
                self.playerVM.startRenderVideoStreamOf(user: owner.user,
                                                       on: leftRender)
                self.playerVM.startRenderVideoStreamOf(user: info.remoteRoom.owner,
                                                       on: rightRender)
                
                self.pkView?.startCountingDown()
                self.pkView?.giftBar.leftValue = info.localRank
                self.pkView?.giftBar.rightValue = info.remoteRank
                self.pkView?.rightLabel.text = info.remoteRoom.owner.info.name
                self.pkView?.countDown = info.countDown
                let height = UIScreen.main.bounds.height - self.pkContainerView.frame.maxY - UIScreen.main.heightOfSafeAreaBottom - 20 - self.bottomToolsVC!.view.bounds.height
                self.chatViewHeight.constant = height
            case .none:
                self.playerVM.startRenderVideoStreamOf(user: owner.user,
                                                       on: self.renderView)
                self.pkView?.stopCountingDown()
                self.chatViewHeight.constant = 219
            default:
                break
            }
        }).disposed(by: bag)
        
        pkVM.receivedInvitation.subscribe(onNext: { (battle) in
            self.showAlert(message: NSLocalizedString("PK_Recieved_Invite"),
                           action1: NSLocalizedString("Reject"),
                           action2: NSLocalizedString("Confirm"),
                           handler1: { [unowned self] (_) in
                            self.pkVM.reject(invitation: battle)
            }) { [unowned self] (_) in
                self.pkVM.accept(invitation: battle)
            }
        }).disposed(by: bag)
        
        pkVM.invitationIsByRejected.subscribe(onNext: { (battle) in
            self.showTextToast(text: NSLocalizedString("PK_Invite_Reject"))
        }).disposed(by: bag)
    }
    
    func intoRemoteRoom() {
        guard let session = ALCenter.shared().liveSession,
            let pkInfo = self.pkVM.state.value.pkInfo else {
            assert(false)
            return
        }
        
        session.leave()
        
        let owner = pkInfo.remoteRoom.owner
        let role = session.role
        let room = Room(name: "",
                        roomId: pkInfo.remoteRoom.roomId,
                        imageURL: "",
                        personCount: 0,
                        owner: pkInfo.remoteRoom.owner)
        
        let newSession = LiveSession(room: room,
                                     videoConfiguration: VideoConfiguration(),
                                     type: .pk,
                                     owner: .otherUser(owner),
                                     role: role)
        
        newSession.join(success: { [unowned newSession, unowned self] (joinedInfo) in
            guard let pkInfo = joinedInfo.pkInfo,
                let vm = try? PKVM(room: joinedInfo.room, state: pkInfo),
                let navigation = self.navigationController else {
                    assert(false)
                    return
            }
            
            ALCenter.shared().liveSession = newSession
            let newPk = UIStoryboard.initViewController(of: "PKBroadcastersViewController",
                                                        class: PKBroadcastersViewController.self)
            newPk.pkVM = vm
            
            navigation.popViewController(animated: false)
            navigation.pushViewController(newPk, animated: false)
        }) { [weak self] in
            self?.showTextToast(text: NSLocalizedString("Join_Other_Live_Room_Fail"))
        }
    }
}

private extension PKBroadcastersViewController {
    func show(result: PKResult) {
        let completion = { [weak self] in
            let view = TextToast(frame: CGRect(x: 0, y: 200, width: 0, height: 44), filletRadius: 8)
            view.text = NSLocalizedString("PK_End")
            self?.showToastView(view, duration: 0.2)
        }
        
        switch result {
        case .win:
            self.pkView?.showWinner(isLeft: true, completion: completion)
        case .draw:
            self.pkView?.showWinner(isLeft: false, completion: completion)
        case .lose:
            self.pkView?.showDraw(completion: completion)
        }
    }
    
    func presentInvitationRoomList() {
        self.showMaskView(color: UIColor.clear)
        
        let vc = UIStoryboard.initViewController(of: "CVUserListViewController",
                                                 class: CVUserListViewController.self,
                                                 on: "Popover")
        
        vc.pkVM = pkVM
        vc.showType = .pk
        vc.view.cornerRadius(10)
        
        let presenetedHeight: CGFloat = 526.0 + UIScreen.main.heightOfSafeAreaTop
        let y = UIScreen.main.bounds.height - presenetedHeight
        let presentedFrame = CGRect(x: 0,
                                    y: y,
                                    width: UIScreen.main.bounds.width,
                                    height: presenetedHeight)
        
        vc.inviteRoom.subscribe(onNext: { [unowned self] (room) in
            self.hiddenMaskView()
            var message: String
            if DeviceAssistant.Language.isChinese {
                message = "你是否要邀请\"\(room.name)\"进行PK?"
            } else {
                message = "Do you send a invitation to \"\(room.name)\"?"
            }
            
            self.showAlert(message: message,
                           action1: NSLocalizedString("Cancel"),
                           action2: NSLocalizedString("Confirm")) { [unowned self] (_) in
                            self.pkVM.sendInvitationTo(room: room)
            }
        }).disposed(by: bag)
        
        vc.accepteApplicationOfRoom.subscribe(onNext: { [unowned self] (battle) in
            self.hiddenMaskView()
            var message: String
            if DeviceAssistant.Language.isChinese {
                message = "你是否要接受\"\(battle.initatorRoom.name)\"的邀请?"
            } else {
                message = "Do you accept \(battle.initatorRoom.name)'s pk invitation?"
            }
            
            self.showAlert(message: message,
                           action1: NSLocalizedString("Cancel"),
                           action2: NSLocalizedString("Confirm")) { [unowned self] (_) in
                            self.pkVM.accept(invitation: battle)
            }
        }).disposed(by: bag)
        
        vc.rejectApplicationOfRoom.subscribe(onNext: { [unowned self] (battle) in
            self.hiddenMaskView()
            var message: String
            if DeviceAssistant.Language.isChinese {
                message = "你是否要拒绝\"\(battle.initatorRoom.name)\"的邀请?"
            } else {
                message = "Do you reject \(battle.initatorRoom.name)'s pk invitation?"
            }
            
            self.showAlert(message: message,
                           action1: NSLocalizedString("Cancel"),
                           action2: NSLocalizedString("Confirm")) { [unowned self] (_) in
                            self.pkVM.reject(invitation: battle)
            }
        }).disposed(by: bag)
        
        self.presentChild(vc,
                          animated: true,
                          presentedFrame: presentedFrame)
    }
}
