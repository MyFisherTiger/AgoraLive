//
//  LiveShoppingViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/7/22.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import MJRefresh
import RxSwift
import RxRelay

class LiveShoppingViewController: MaskViewController, LiveViewController {
    @IBOutlet weak var ownerView: IconTextView!
    @IBOutlet weak var pkContainerView: UIView!
    @IBOutlet weak var renderView: UIView!
    @IBOutlet weak var pkButton: UIButton!
    @IBOutlet weak var chatViewHeight: NSLayoutConstraint!
    
    private var popover = Popover(options: [.type(.up),
                                            .blackOverlayColor(UIColor.clear),
                                            .cornerRadius(5.0),
                                            .arrowSize(CGSize(width: 8, height: 4))])
    private var popoverContent = UILabel(frame: CGRect.zero)
    
    private var pkView: PKViewController?
    private var roomListVM = LiveListVM()
    private var goodsVM = GoodsVM()
    var pkVM: PKVM!
    
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
    var audienceListVM = LiveUserListVM()
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
        extralBottomTools(session: session)
        chatInput()
        musicList()
        netMonitor()
//        PK(session: session)
        
        goods(session: session)
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

extension LiveShoppingViewController {
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
    }
    
    func extralBottomTools(session: LiveSession) {
        guard let bottomToolsVC = self.bottomToolsVC else {
            return
        }
        
        bottomToolsVC.shoppingButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.presentGoodsList()
        }).disposed(by: bag)
        
        bottomToolsVC.pkButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.presentInvitationList()
        }).disposed(by: bag)
        
        bottomToolsVC.closeButton.rx.tap.subscribe(onNext: { [unowned self] () in
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
            
            
            self.presentInvitationList()
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
            self.pkButton.isHidden = owner.isLocal
            
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
                self.pkVM.accpet(invitation: battle)
            }
        }).disposed(by: bag)
        
        pkVM.invitationIsByRejected.subscribe(onNext: { (battle) in
            self.showTextToast(text: NSLocalizedString("PK_Invite_Reject"))
        }).disposed(by: bag)
    }
    
    func goods(session: LiveSession) {
        
        guard !session.owner.value.isLocal else {
            return
        }
        
        // audience
        goodsVM.itemOnShelf.subscribe(onNext: { [unowned self] (item) in
            guard let shoppingButton = self.bottomToolsVC?.shoppingButton else {
                return
            }
            
            let notification = item.name + " " + NSLocalizedString("Product_On_Shelf_Notification")
            let popoverContentHeight: CGFloat = 22
            let size = notification.size(font: UIFont.systemFont(ofSize: 14),
                              drawRange: CGSize(width: CGFloat(MAXFLOAT), height: popoverContentHeight))

            self.popoverContent.frame = CGRect(x: 0,
                                               y: 0,
                                               width: size.width,
                                               height: popoverContentHeight)
            self.popover.show(self.popoverContent, fromView: shoppingButton)
        }).disposed(by: bag)
    }
    
    func presentGoodsList() {
        guard let session = ALCenter.shared().liveSession else {
                assert(false)
                return
        }
        
        self.showMaskView(color: UIColor.clear)
        
        let roomId = session.roomId
        
        let vc = UIStoryboard.initViewController(of: "GoodsListViewController",
                                                 class: GoodsListViewController.self,
                                                 on: "Popover")
        
        vc.vm = goodsVM
        vc.view.cornerRadius(10)
        
        let presenetedHeight: CGFloat = UIScreen.main.bounds.height - 82 - 50
        let y = UIScreen.main.bounds.height - presenetedHeight
        let presentedFrame = CGRect(x: 0,
                                    y: y,
                                    width: UIScreen.main.bounds.width,
                                    height: presenetedHeight)
        
        self.presentChild(vc,
                          animated: true,
                          presentedFrame: presentedFrame)
    }
    
    func intoRemoteRoom() {
        guard let session = ALCenter.shared().liveSession,
            let pkInfo = self.pkVM.state.value.pkInfo else {
            assert(false)
            return
        }
        
        session.leave()
        
        let settings = LocalLiveSettings(title: "")
        let owner = pkInfo.remoteRoom.owner
        let role = session.role
        
        let newSession = LiveSession(roomId: pkInfo.remoteRoom.roomId,
                                     settings: settings,
                                     type: .pk,
                                     owner: .otherUser(owner),
                                     role: role)
        
        newSession.join(success: { [unowned newSession, unowned self] (joinedInfo) in
            guard let pkInfo = joinedInfo.pkInfo,
                let vm = try? PKVM(dic: pkInfo),
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

private extension LiveShoppingViewController {
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
    
    func presentInvitationList() {
        self.showMaskView(color: UIColor.clear) { [unowned self] in
            self.userListVC = nil
        }
        
        guard let session = ALCenter.shared().liveSession else {
                assert(false)
                return
        }
        
        let roomId = session.roomId
        
        let vc = UIStoryboard.initViewController(of: "UserListViewController",
                                                       class: UserListViewController.self,
                                                       on: "Popover")
        
        self.userListVC = vc
        
        vc.showType = .pk
        vc.view.cornerRadius(10)
        
        let presenetedHeight: CGFloat = UIScreen.main.heightOfSafeAreaTop + 526.0 + 50.0
        let y = UIScreen.main.bounds.height - presenetedHeight
        let presentedFrame = CGRect(x: 0,
                                    y: y,
                                    width: UIScreen.main.bounds.width,
                                    height: presenetedHeight)
        
        self.presentChild(vc,
                          animated: true,
                          presentedFrame: presentedFrame)
        
        // Room List
        roomListVM.presentingType = .pk
        roomListVM.refetch()
        
        vc.tableView.mj_header = MJRefreshNormalHeader(refreshingBlock: { [unowned self, unowned vc] in
            self.roomListVM.refetch(success: {
                vc.tableView.mj_header?.endRefreshing()
            }) { [unowned vc] in // fail
                vc.tableView.mj_header?.endRefreshing()
            }
        })
        
        vc.tableView.mj_footer = MJRefreshBackFooter(refreshingBlock: { [unowned self, unowned vc] in
            self.roomListVM.fetch(success: {
                vc.tableView.mj_footer?.endRefreshing()
            }) { [unowned vc] in // fail
                vc.tableView.mj_footer?.endRefreshing()
            }
        })
        
        vc.selectedInviteRoom.subscribe(onNext: { [unowned self] (room) in
            self.hiddenMaskView()
            self.userListVC = nil
            
            self.pkVM.sendInvitationTo(room: room) { [unowned self] (error) in
                self.showTextToast(text: NSLocalizedString("PK_Invite_Fail"))
            }
        }).disposed(by: bag)
        
        if let userListVC = userListVC {
            roomListVM.presentingList.map { (list) -> [RoomBrief] in
                var newList = list
                let index = newList.firstIndex { (room) -> Bool in
                    return roomId == room.roomId
                }
                
                if let index = index {
                    newList.remove(at: index)
                }
                
                return newList
            }.bind(to: userListVC.roomList).disposed(by: bag)
        }
    }
}
