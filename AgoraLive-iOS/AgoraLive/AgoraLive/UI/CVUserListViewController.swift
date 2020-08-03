//
//  CVUserListViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/7/31.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
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
        case none, inviting, avaliableInvite
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
            case .avaliableInvite:
                inviteButton.isHidden = false
                inviteButton.isEnabled = true
                inviteButton.setTitle(NSLocalizedString("Invite"), for: .normal)
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
    
    enum ShowType {
        case multiHosts, pk, onlyUser
    }
    
    private let bag = DisposeBag()
    
    // Rx
    private(set) var userList = BehaviorRelay(value: [LiveRole]())
    private(set) var roomList = BehaviorRelay(value: [RoomBrief]())
    
    let inviteUser = PublishRelay<LiveRole>()
    
    let rejectApplicationOfUser = PublishRelay<LiveRole>()
    let accepteApplicationOfUser = PublishRelay<LiveRole>()
    
    let inviteRoom = PublishRelay<RoomBrief>()
    
    var showType: ShowType = .onlyUser
    
    var userListVM: LiveUserListVM!
    var roomListVM: LiveListVM!
    var multiHostsVM: MultiHostsVM!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.rowHeight = 48
        
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
            userListVM.list.bind(to: tableView.rx.items(cellIdentifier: "CVUserInvitationListCell",
                                                        cellType: CVUserInvitationListCell.self)) { [unowned images] (index, user, cell) in
                                                            cell.buttonState = .none
                                                            cell.headImageView.image = images.getHead(index: user.info.imageIndex)
            }.disposed(by: bag)
        case .multiHosts:
            userListVM.list.bind(to: tableView.rx.items(cellIdentifier: "CVUserInvitationListCell",
                                                        cellType: CVUserInvitationListCell.self)) { [unowned images, unowned self] (index, user, cell) in
                                                            let local = ALCenter.shared().centerProvideLocalUser()
                                                            var buttonState = CVUserInvitationListCell.InviteButtonState.avaliableInvite
                                                            
                                                            for item in self.multiHostsVM.applyingUserList.value where user.info.userId == item.info.userId {
                                                                buttonState = .inviting
                                                                break
                                                            }
                                                            
                                                            if user.info.userId == local.info.value.userId {
                                                                buttonState = .none
                                                            }
                                                            
                                                            cell.buttonState = buttonState
                                                            cell.inviteButton.isHidden = false
                                                            cell.headImageView.image = images.getHead(index: user.info.imageIndex)
                                                            cell.index = index
                                                            cell.delegate = self
            }.disposed(by: bag)
            
            multiHostsVM.applyingUserList.bind(to: tableView.rx.items(cellIdentifier: "CVUserApplicationListCell",
                                                                      cellType: CVUserApplicationListCell.self)) { [unowned images, unowned self] (index, user, cell) in
                                                                        cell.headImageView.image = images.getHead(index: user.info.imageIndex)
                                                                        cell.index = index
                                                                        cell.delegate = self
            }.disposed(by: bag)
        case .pk:
            break
        }
    }
}

/*
extension CVUserListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch showType {
        case .onlyUser:
            return userListVM.list.value.count
        case .multiHosts:
            // All user
            if tabView.selectedIndex.value == 0 {
                return userListVM.list.value.count
                
            // Application
            } else {
                return multiHostsVM.applyingUserList.value.count
            }
        case .pk:
            return roomListVM.presentingList.value.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let images = ALCenter.shared().centerProvideImagesHelper()
        
        switch showType {
        case .onlyUser:
            let user = userList.value[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "CVUserInvitationListCell", for: indexPath) as! CVUserInvitationListCell
            cell.buttonState = .none
            cell.headImageView.image = images.getHead(index: user.info.imageIndex)
            return cell
        case .multiHosts:
            let local = ALCenter.shared().centerProvideLocalUser()
            let user = userList.value[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "CVUserInvitationListCell", for: indexPath) as! CVUserInvitationListCell
            
            // All user
            if tabView.selectedIndex.value == 0 {
                var buttonState = CVUserInvitationListCell.InviteButtonState.avaliableInvite
                
                for item in multiHostsVM.applyingUserList.value where user.info.userId == item.info.userId {
                    buttonState = .inviting
                    break
                }
                
                if user.info.userId == local.info.value.userId {
                    buttonState = .none
                }
                
                cell.buttonState = buttonState
                cell.inviteButton.isHidden = false
                cell.headImageView.image = images.getHead(index: user.info.imageIndex)
                return cell
                
            // Application
            } else {
                let user = multiHostsVM.applyingUserList.value[indexPath.row]
                let cell = tableView.dequeueReusableCell(withIdentifier: "CVUserApplicationListCell", for: indexPath) as! CVUserApplicationListCell
                cell.headImageView.image = images.getHead(index: user.info.imageIndex)
                return cell
            }
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "CVUserApplicationListCell", for: indexPath) as! CVUserApplicationListCell
            return cell
        }
    }
}
 */

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
