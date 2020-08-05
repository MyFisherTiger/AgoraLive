//
//  CVUserListViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/7/31.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import MJRefresh
import RxSwift
import RxRelay

protocol CVUserInvitationListCellDelegate: NSObjectProtocol {
    func cell(_ cell: CVUserInvitationListCell, didTapInvitationButton: UIButton, on index: Int)
}

protocol CVUserApplicationListCellDelegate: NSObjectProtocol {
    func cell(_ cell: CVUserApplicationListCell, didTapAcceptButton: UIButton, on index: Int)
    func cell(_ cell: CVUserApplicationListCell, didTapRejectButton: UIButton, on index: Int)
}

class CVUserInvitationListCell: UITableViewCell {
    enum InviteButtonState {
        case none, inviting, availableInvite
    }
    
    @IBOutlet var headImageView: UIImageView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet weak var inviteButton: UIButton!
    
    fileprivate weak var delegate: CVUserInvitationListCellDelegate?
    private let bag = DisposeBag()
    
    var index: Int = 0
    var buttonState: InviteButtonState = .none {
        didSet {
            switch buttonState {
            case .none:
                inviteButton.isHidden = true
            case .inviting:
                inviteButton.isHidden = false
                inviteButton.isEnabled = false
                inviteButton.setTitle(NSLocalizedString("Inviting"), for: .disabled)
                inviteButton.setTitleColor(.white, for: .normal)
                inviteButton.backgroundColor = UIColor(hexString: "#CCCCCC")
                inviteButton.cornerRadius(16)
            case .availableInvite:
                inviteButton.isHidden = false
                inviteButton.isEnabled = true
                inviteButton.setTitle(NSLocalizedString("Invite"), for: .normal)
                inviteButton.setTitleColor(UIColor(hexString: "#0088EB"), for: .normal)
                inviteButton.backgroundColor = .white
                inviteButton.layer.borderWidth = 2
                inviteButton.layer.borderColor = UIColor(hexString: "#CCCCCC").cgColor
                inviteButton.cornerRadius(16)
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let color = UIColor(hexString: "#D8D8D8")
        let x: CGFloat = 15.0
        let width = UIScreen.main.bounds.width - (x * 2)
        self.contentView.containUnderline(color,
                                          x: x,
                                          width: width)
        
        self.inviteButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.delegate?.cell(self, didTapInvitationButton: self.inviteButton, on: self.index)
        }).disposed(by: bag)
    }
}

class CVUserApplicationListCell: UITableViewCell {
    @IBOutlet weak var headImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var rejectButton: UIButton!
    
    fileprivate weak var delegate: CVUserApplicationListCellDelegate?
    private let bag = DisposeBag()
    
    var index: Int = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let color = UIColor(hexString: "#D8D8D8")
        let x: CGFloat = 15.0
        let width = UIScreen.main.bounds.width - (x * 2)
        self.contentView.containUnderline(color,
                                          x: x,
                                          width: width)
        
        self.acceptButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.delegate?.cell(self, didTapAcceptButton: self.acceptButton, on: self.index)
        }).disposed(by: bag)
        
        self.rejectButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.delegate?.cell(self, didTapRejectButton: self.rejectButton, on: self.index)
        }).disposed(by: bag)
    }
}

class CVUserListViewController: UIViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tabView: TabSelectView!
    @IBOutlet weak var tableViewTop: NSLayoutConstraint!
    @IBOutlet weak var tableViewBottom: NSLayoutConstraint!
    
    enum ShowType {
        case multiHosts, pk, onlyUser
    }
    
    private let bag = DisposeBag()
    private var userListSubscribeOnMultiHosts: Disposable?
    private var applyingUserListSubscribeOnMultiHosts: Disposable?
    
    // Rx
    private(set) var userList = BehaviorRelay(value: [LiveRole]())
    private(set) var roomList = BehaviorRelay(value: [Room]())
    
    let inviteUser = PublishRelay<LiveRole>()
    
    let rejectApplicationOfUser = PublishRelay<LiveRole>()
    let accepteApplicationOfUser = PublishRelay<LiveRole>()
    
    let inviteRoom = PublishRelay<Room>()
    
    var showType: ShowType = .onlyUser
    
    
    var userListVM: LiveUserListVM!
    var multiHostsVM: MultiHostsVM!
    
    var pkVM: PKVM!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = 48
        tableViewBottom.constant = UIScreen.main.heightOfSafeAreaBottom
        
        tabView.underlineWidth = 68
        tabView.alignment = .center
        tabView.titleSpace = 80
        tabView.underlineHeight = 3
        
        switch showType {
        case .multiHosts:
            titleLabel.text = NSLocalizedString("Online_User")
            let titles = [NSLocalizedString("All"), NSLocalizedString("ApplicationOfBroadcasting")]
            tabView.update(titles)
        case .pk:
            titleLabel.text = NSLocalizedString("Invite_PK")
            let titles = [NSLocalizedString("PK_Invitation"), NSLocalizedString("PK_Application")]
            tabView.update(titles)
        case .onlyUser:
            titleLabel.text = NSLocalizedString("Online_User")
            tabView.isHidden = true
            tableViewTop.constant = 0
        }
        
        let images = ALCenter.shared().centerProvideImagesHelper()
        
        switch showType {
        case .onlyUser:
            userListVM.refetch(onlyAudience: false)
            userListVM.list.bind(to: tableView.rx.items(cellIdentifier: "CVUserInvitationListCell",
                                                        cellType: CVUserInvitationListCell.self)) { [unowned images] (index, user, cell) in
                                                            cell.nameLabel.text = user.info.name
                                                            cell.buttonState = .none
                                                            cell.headImageView.image = images.getHead(index: user.info.imageIndex)
            }.disposed(by: bag)
        case .multiHosts:
            tabView.selectedIndex.subscribe(onNext: { [unowned self] (index) in
                switch index {
                case 0:
                    if let subscribe = self.applyingUserListSubscribeOnMultiHosts {
                        subscribe.dispose()
                    }
                    
                    self.userListSubscribeOnMultiHosts = self.tableViewBindWithAllUser()
                    self.userListSubscribeOnMultiHosts?.disposed(by: self.bag)
                    
                    self.userListVM.refetch(onlyAudience: false)
                case 1:
                    if let subscribe = self.userListSubscribeOnMultiHosts {
                        subscribe.dispose()
                    }
                    
                    self.applyingUserListSubscribeOnMultiHosts = self.tableViewBindWithApplicationsFromUser()
                    self.applyingUserListSubscribeOnMultiHosts?.disposed(by: self.bag)
                default:
                    break
                }
            }).disposed(by: bag)
        case .pk:
            tabView.selectedIndex.subscribe(onNext: { (index) in
                
            }).disposed(by: bag)
        }
                
        tableView.mj_header = MJRefreshNormalHeader(refreshingBlock: { [unowned self] in
            let endRefetch: Completion = { [unowned self] in
                self.tableView.mj_header?.endRefreshing()
            }
            
            switch self.showType {
            case .onlyUser:
                self.userListVM.refetch(onlyAudience: false, success: endRefetch, fail: endRefetch)
            case .multiHosts:
                if self.tabView.selectedIndex.value == 0 {
                    self.userListVM.refetch(onlyAudience: false, success: endRefetch, fail: endRefetch)
                } else {
                    let list = self.multiHostsVM.applyingUserList.value
                    self.multiHostsVM.applyingUserList.accept(list)
                }
            case .pk:
                break
            }
        })
        
        tableView.mj_footer = MJRefreshBackFooter(refreshingBlock: { [unowned self] in
            let endRefetch: Completion = { [unowned self] in
                self.tableView.mj_footer?.endRefreshing()
            }
            
            switch self.showType {
            case .onlyUser:
                self.userListVM.fetch(onlyAudience: false, success: endRefetch, fail: endRefetch)
            case .multiHosts:
                if self.tabView.selectedIndex.value == 0 {
                    self.userListVM.fetch(onlyAudience: false, success: endRefetch, fail: endRefetch)
                } else {
                    let list = self.multiHostsVM.applyingUserList.value
                    self.multiHostsVM.applyingUserList.accept(list)
                }
            case .pk:
                break
            }
        })
    }
}

private extension CVUserListViewController {
    func tableViewBindWithAllUser() -> Disposable {
        let images = ALCenter.shared().centerProvideImagesHelper()
        
        let subscribe = userListVM.list.bind(to: tableView
            .rx.items(cellIdentifier: "CVUserInvitationListCell",
                      cellType: CVUserInvitationListCell.self)) { [unowned images, unowned self] (index, user, cell) in
                        var buttonState = CVUserInvitationListCell.InviteButtonState.availableInvite
                        
                        for item in self.multiHostsVM.invitingUserList.value where user.info.userId == item.info.userId {
                            buttonState = .inviting
                            break
                        }
                        
                        if user.type != .audience {
                            buttonState = .none
                        }
                        
                        cell.nameLabel.text = user.info.name
                        cell.buttonState = buttonState
                        cell.headImageView.image = images.getHead(index: user.info.imageIndex)
                        cell.index = index
                        cell.delegate = self
        }
        
        return subscribe
    }
    
    func tableViewBindWithApplicationsFromUser() -> Disposable {
        let images = ALCenter.shared().centerProvideImagesHelper()
        
        let subscribe = multiHostsVM.applyingUserList.bind(to: tableView
            .rx.items(cellIdentifier: "CVUserApplicationListCell",
                      cellType: CVUserApplicationListCell.self)) { [unowned images, unowned self] (index, user, cell) in
                        cell.nameLabel.text = user.info.name
                        cell.headImageView.image = images.getHead(index: user.info.imageIndex)
                        cell.index = index
                        cell.delegate = self
        }
        
        return subscribe
    }
    
    func tableViewBindWithAvailableRooms() -> Disposable {
        let images = ALCenter.shared().centerProvideImagesHelper()
        
        let subscribe = pkVM.availableRooms.bind(to: tableView
            .rx.items(cellIdentifier: "CVUserInvitationListCell",
                      cellType: CVUserInvitationListCell.self)) { [unowned images, unowned self] (index, room, cell) in
                        var buttonState = CVUserInvitationListCell.InviteButtonState.availableInvite
                        
                        for item in self.pkVM.invitingRoomList.value where room.roomId == item.roomId {
                            buttonState = .inviting
                            break
                        }
                        
                        cell.nameLabel.text = room.name
                        cell.buttonState = buttonState
                        cell.headImageView.image = images.getRoom(index: room.imageIndex)
                        cell.index = index
                        cell.delegate = self
        }
        
        return subscribe
    }
    
    func tableViewBindWithApplicationsFromRom() -> Disposable {
        let images = ALCenter.shared().centerProvideImagesHelper()
        
        let subscribe = pkVM.applyingRoomList.bind(to: tableView
            .rx.items(cellIdentifier: "CVUserApplicationListCell",
                      cellType: CVUserApplicationListCell.self)) { [unowned images, unowned self] (index, room, cell) in
                        cell.nameLabel.text = room.name
                        cell.headImageView.image = images.getRoom(index: room.imageIndex)
                        cell.index = index
                        cell.delegate = self
        }
        
        return subscribe
    }
}

extension CVUserListViewController: CVUserInvitationListCellDelegate {
    func cell(_ cell: CVUserInvitationListCell, didTapInvitationButton: UIButton, on index: Int) {
        let user = userListVM.list.value[index]
        inviteUser.accept(user)
    }
}

extension CVUserListViewController: CVUserApplicationListCellDelegate {
    func cell(_ cell: CVUserApplicationListCell, didTapAcceptButton: UIButton, on index: Int) {
        let user = multiHostsVM.applyingUserList.value[index]
        accepteApplicationOfUser.accept(user)
    }
    
    func cell(_ cell: CVUserApplicationListCell, didTapRejectButton: UIButton, on index: Int) {
        let user = multiHostsVM.applyingUserList.value[index]
        rejectApplicationOfUser.accept(user)
    }
}
