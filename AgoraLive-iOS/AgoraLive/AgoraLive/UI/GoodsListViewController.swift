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

class GoodsCell: UITableViewCell {
    enum ButtonType {
        case onShelf, offShelf, detail
    }
    
    @IBOutlet weak var goodsImageView: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var filletView: FilletView!
    
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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        filletView.insideBackgroundColor = .white
        filletView.filletRadius = 4
    }
}

class GoodsListViewController: UIViewController, RxViewController {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tabView: TabSelectView!
    @IBOutlet weak var tableView: UITableView!
    
    private var onSelfSubscribe: Disposable?
    private var offSelfSubscribe: Disposable?
    
    var bag = DisposeBag()
    private lazy var vm = GoodsVM()
    
    var perspective: LiveRoleType = .owner
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
                
        vm.fake()
        
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
                                                                
                                                                if self.perspective == .owner {
                                                                    cell.buttonType = goods.isSale ? .onShelf : .offShelf
                                                                } else {
                                                                    cell.buttonType = .detail
                                                                }
        }
        
        return subscribe
    }
}
