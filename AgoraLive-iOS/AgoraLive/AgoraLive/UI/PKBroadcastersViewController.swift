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
    private var roomListVM = LiveListVM()
    var pkVM: PKVM!
    
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
        guard let owner = session.owner else {
            assert(false)
            return
        }
        
        let images = ALCenter.shared().centerProvideImagesHelper()
        
        ownerView.offsetLeftX = -14
        ownerView.offsetRightX = 5
        ownerView.label.textColor = .white
        ownerView.label.font = UIFont.systemFont(ofSize: 11)
        ownerView.backgroundColor = tintColor
        
        switch owner {
        case .localUser(let user):
            ownerView.label.text = user.info.name
            ownerView.imageView.image = images.getHead(index: user.info.imageIndex)
            deviceVM.camera = .on
            deviceVM.mic = .on
            pkView?.intoOtherButton.isHidden = true
            pkButton.isHidden = false
        case .otherUser(let remote):
            ownerView.label.text = remote.info.name
            ownerView.imageView.image = images.getHead(index: remote.info.imageIndex)
            deviceVM.camera = .off
            deviceVM.mic = .off
            pkView?.intoOtherButton.isHidden = false
            pkButton.isHidden = true
        }
        
        bottomToolsVC?.closeButton.rx.tap.subscribe(onNext: { [unowned self] () in
            if self.pkVM.statistics.value.state.isDuring {
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
        pkView?.intoOtherButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.intoOtherRoom()
        }).disposed(by: bag)
        
        pkVM.statistics.subscribe(onNext: { [unowned self] (statistics) in
            self.showResult(statistics: statistics)
        }).disposed(by: bag)
        
        pkButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.showMaskView(color: UIColor.clear) { [unowned self] in
                self.hiddenMaskView()
                self.hiddenInviteList()
            }
            
            self.presentInviteList()
        }).disposed(by: bag)
        
        // PK VM
        let roomId = session.roomId
        
        pkVM.receivedPKInvite.subscribe(onNext: { [unowned self] (room) in
            self.showAlert(message: NSLocalizedString("PK_Recieved_Invite"),
                           action1: NSLocalizedString("Reject"),
                           action2: NSLocalizedString("Confirm"),
                           handler1: { [unowned self] (_) in
                            guard let role = ALCenter.shared().liveSession?.role else {
                                assert(false)
                                return
                            }
                            
                            self.pkVM.rejectPK(localRoom: roomId, localUser: role, inviteRoom: room)
            }) { [unowned self] (_) in
                self.pkVM.startPK(action: .on,
                                  roomId: roomId,
                                  opponentRoomId: room.roomId) { [unowned self] (_) in
                                    self.showAlert(message: NSLocalizedString("PK_Invite_Fail"))
                }
            }
        }).disposed(by: bag)
        
        pkVM.receivedPKReject.subscribe(onNext: { [unowned self] (room) in
            self.showAlert(message: NSLocalizedString("PK_Invite_Reject"))
        }).disposed(by: bag)
    }
    
    func intoOtherRoom() {
        guard let session = ALCenter.shared().liveSession else {
            assert(false)
            return
        }
        
        session.leave()
        
        let fail: Completion = {
            self.showAlert(NSLocalizedString("Join_Other_Live_Room_Fail"))
        }
        
        let settings = LocalLiveSettings(title: "")
        let newSession = LiveSession(roomId: pkVM.statistics.value.opponentRoomId, settings: settings, type: .pkBroadcasters)
        newSession.join(success: { [unowned newSession, unowned self] (joinedInfo) in
            ALCenter.shared().liveSession = newSession
            let newPk = UIStoryboard.initViewController(of: "PKBroadcastersViewController",
                                                        class: PKBroadcastersViewController.self)
            
            var statistics: PKStatistics
            
            if let pkInfo = joinedInfo.pkInfo {
                statistics = try! PKStatistics(dic: pkInfo)
            } else {
                statistics = PKStatistics(state: .none)
            }
            
            newPk.pkVM = PKVM(statistics: statistics)
            guard let navigation = self.navigationController else {
                return
            }
            navigation.popViewController(animated: false)
            navigation.pushViewController(newPk, animated: false)
        }, fail: fail)
    }
}

private extension PKBroadcastersViewController {
    func showResult(statistics: PKStatistics) {
        if let result = statistics.state.hasResult {
            let completion = { [weak self] in
                let view = TextToast(frame: CGRect(x: 0, y: 200, width: 0, height: 44), filletRadius: 8)
                view.text = NSLocalizedString("PK_End")
                self?.showToastView(view, duration: 0.2)
                self?.updateViewsWith(statistics: statistics)
            }
            
            switch result {
            case .success:
                self.pkView?.showWinner(isLeft: true, completion: completion)
            case .fail:
                self.pkView?.showWinner(isLeft: false, completion: completion)
            case .draw:
                self.pkView?.showDraw(completion: completion)
            }
        } else {
            updateViewsWith(statistics: statistics)
        }
    }
    
    func updateViewsWith(statistics: PKStatistics) {
        guard let session = ALCenter.shared().liveSession,
            let owner = session.owner else {
                return
        }
        
        renderView.isHidden = statistics.state.isDuring
        pkContainerView.isHidden = !statistics.state.isDuring
        
        switch (owner, statistics.state.isDuring) {
        case (.localUser(let user), false):
            playerVM.startRenderLocalVideoStream(id: user.agUId,
                                                 view: renderView)
            pkButton.isHidden = false
        case (.otherUser(let user), false):
            playerVM.startRenderRemoteVideoStream(id: user.agUId,
                                             view: renderView)
            pkButton.isHidden = true
        case (.localUser(let user), true):
            guard let pkView = self.pkView else {
                assert(false)
                return
            }
            
            let leftRenderView = pkView.leftRenderView
            let rightRenderView = pkView.rightRenderView
            
            playerVM.startRenderLocalVideoStream(id: user.agUId,
                                                 view: leftRenderView!)
            
            let opponentUser = statistics.opponentOwner!.agUId
            playerVM.startRenderRemoteVideoStream(id: opponentUser,
                                             view: rightRenderView!)
            pkButton.isHidden = true
        case (.otherUser(let user), true):
            guard let pkView = self.pkView else {
                assert(false)
                return
            }
            
            let leftRenderView = pkView.leftRenderView
            let rightRenderView = pkView.rightRenderView
            
            playerVM.startRenderRemoteVideoStream(id: user.agUId,
                                             view: leftRenderView!)
            
            let opponentUser = statistics.opponentOwner!.agUId
            playerVM.startRenderRemoteVideoStream(id: opponentUser,
                                             view: rightRenderView!)
            pkButton.isHidden = true
        }
        
        self.pkView?.countDown = statistics.countDown
        
        if statistics.state.isDuring {
            self.pkView?.startCountingDown()
            self.pkView?.giftBar.leftValue = statistics.currentGift
            self.pkView?.giftBar.rightValue = statistics.opponentGift
            self.pkView?.rightLabel.text = statistics.opponentOwner!.info.name
            let height = UIScreen.main.bounds.height - self.pkContainerView.frame.maxY - UIScreen.main.heightOfSafeAreaBottom - 20 - self.bottomToolsVC!.view.bounds.height
            self.chatViewHeight.constant = height
        } else {
            self.pkView?.stopCountingDown()
            self.chatViewHeight.constant = 219
        }
    }
    
    func presentInviteList() {
        guard let session = ALCenter.shared().liveSession,
            let role = session.role else {
                assert(false)
                return
        }
        
        let roomId = session.roomId
        
        let inviteVC = UIStoryboard.initViewController(of: "UserListViewController",
                                                       class: UserListViewController.self)
        
        self.userListVC = inviteVC
        
        inviteVC.showType = .pk
        inviteVC.view.cornerRadius(10)
        
        let presenetedHeight: CGFloat = UIScreen.main.heightOfSafeAreaTop + 526.0 + 50.0
        let y = UIScreen.main.bounds.height - presenetedHeight
        let presentedFrame = CGRect(x: 0,
                                    y: y,
                                    width: UIScreen.main.bounds.width,
                                    height: presenetedHeight)
        
        self.presentChild(inviteVC,
                          animated: true,
                          presentedFrame: presentedFrame)
        
        // Room List
        roomListVM.presentingType = .pkBroadcasters
        roomListVM.refetch()
        
        inviteVC.tableView.mj_header = MJRefreshNormalHeader(refreshingBlock: { [unowned self, unowned inviteVC] in
            self.roomListVM.refetch(success: {
                inviteVC.tableView.mj_header?.endRefreshing()
            }) { [unowned inviteVC] in // fail
                inviteVC.tableView.mj_header?.endRefreshing()
            }
        })
        
        inviteVC.tableView.mj_footer = MJRefreshBackFooter(refreshingBlock: { [unowned self, unowned inviteVC] in
            self.roomListVM.fetch(success: {
                inviteVC.tableView.mj_footer?.endRefreshing()
            }) { [unowned inviteVC] in // fail
                inviteVC.tableView.mj_footer?.endRefreshing()
            }
        })
        
        inviteVC.selectedInviteRoom.subscribe(onNext: { [unowned self] (room) in
            self.hiddenMaskView()
            self.hiddenInviteList()
            
            self.pkVM.invitePK(localRoom: roomId, localUser: role, inviteRoom: room) { (error) in
                self.showAlert(message: NSLocalizedString("PK_Invite_Fail"))
            }
        }).disposed(by: bag)
        
        roomListVM.presentingList.subscribe(onNext: { [unowned self] (list) in
            var newList = list
            let index = newList.firstIndex { (room) -> Bool in
                return roomId == room.roomId
            }
            
            if let index = index {
                newList.remove(at: index)
            }
            
            self.userListVC?.roomList = newList
        }).disposed(by: bag)
    }
    
    func hiddenInviteList() {
        if let vc = self.userListVC {
            self.dismissChild(vc, animated: true)
            self.userListVC = nil
        }
    }
}
