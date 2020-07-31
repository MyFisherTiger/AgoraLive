//
//  GoodsListViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/7/29.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay

protocol GoodsCellDelegate: NSObjectProtocol {
    func cell(_ cell: GoodsCell, didTapButton: UIButton, on index: Int, for event: GoodsCell.ButtonType)
}

class GoodsCell: UITableViewCell {
    enum ButtonType {
        case onShelf, offShelf, detail
    }
    
    @IBOutlet weak var goodsImageView: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var filletView: FilletView!
    
    private let bag = DisposeBag()
    
    weak var delegate: GoodsCellDelegate?
    
    var buttonType: ButtonType = .onShelf {
        didSet {
            switch buttonType {
            case .onShelf:
                button.setTitle(NSLocalizedString("Product_Launch"), for: .normal)
            case .offShelf:
                button.setTitle(NSLocalizedString("Product_Off_Shelf"), for: .normal)
            case .detail:
                button.setTitle(NSLocalizedString("Product_Go"), for: .normal)
            }
        }
    }
    
    var index: Int = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
        filletView.insideBackgroundColor = .white
        filletView.filletRadius = 4
        
        button.rx.tap.subscribe(onNext: { [unowned self] in
            self.delegate?.cell(self, didTapButton: self.button, on: self.index, for: self.buttonType)
        }).disposed(by: bag)
    }
}

class GoodsListViewController: UIViewController, RxViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tabView: TabSelectView!
    @IBOutlet weak var tableView: UITableView!
    
    
    private var onSelfSubscribe: Disposable?
    private var offSelfSubscribe: Disposable?
    
    var perspective: LiveRoleType = .owner
    var bag = DisposeBag()
    var vm: GoodsVM!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let session = ALCenter.shared().liveSession else {
            assert(false)
            return
        }
        
        views()
        vm.refetchList(of: session.roomId)
    }
}

private extension GoodsListViewController {
    func views() {
        titleLabel.text = NSLocalizedString("Product_List")
        
        let goodsTitles = [NSLocalizedString("Product_Pending"),
                            NSLocalizedString("Product_OnShelf")]
        
        tabView.alignment = .center
        tabView.underlineHeight = 2
        tabView.selectedTitle = TabSelectView.TitleProperty(color: UIColor(hexString: "#333333"),
                                                            font: UIFont.systemFont(ofSize: 14, weight: .medium))
        tabView.unselectedTitle = TabSelectView.TitleProperty(color: UIColor(hexString: "#666666"),
                                                              font: UIFont.systemFont(ofSize: 14))
        tabView.titleSpace = 86
        tabView.update(goodsTitles)
                
        tabView.selectedIndex.subscribe(onNext: { [unowned self] (index) in
            switch index {
            case 0:
                if let subscribe = self.offSelfSubscribe {
                    subscribe.dispose()
                }
                    
                self.onSelfSubscribe = self.tableViewBindWithList(self.vm.onShelfList)
                self.onSelfSubscribe?.disposed(by: self.bag)
            case 1:
                if let subscribe = self.onSelfSubscribe {
                    subscribe.dispose()
                }

                self.offSelfSubscribe = self.tableViewBindWithList(self.vm.offShelfList)
                self.offSelfSubscribe?.disposed(by: self.bag)
            default:
                break
            }
        }).disposed(by: bag)
    }
}

private extension GoodsListViewController {
    func tableViewBindWithList(_ list: BehaviorRelay<[GoodsItem]>) -> Disposable {
        let subscribe = list.bind(to: self.tableView.rx.items(cellIdentifier: "GoodsCell",
                                                              cellType: GoodsCell.self)) { [unowned self] (index, goods, cell) in
                                                                cell.descriptionLabel.text = goods.description
                                                                cell.priceLabel.text = "\(goods.price)"
                                                                
                                                                cell.delegate = self
                                                                
                                                                if self.perspective == .owner {
                                                                    cell.buttonType = goods.isSale ? .onShelf : .offShelf
                                                                } else {
                                                                    cell.buttonType = .detail
                                                                }
        }
        
        return subscribe
    }
}

extension GoodsListViewController: GoodsCellDelegate {
    func cell(_ cell: GoodsCell, didTapButton: UIButton, on index: Int, for event: GoodsCell.ButtonType) {
        guard let session = ALCenter.shared().liveSession else {
            return
        }
        
        let item = vm.list.value[index]
        
        switch event {
        case .onShelf:
            vm.itemOnShelf(item, of: session.roomId)
        case .offShelf:
            vm.itemOffShelf(item, of: session.roomId)
        case .detail:
            break
        }
    }
}
