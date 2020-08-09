//
//  ProductDetailViewController.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/8/8.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay

class ProductDetailViewController: UIViewController, ShowAlertProtocol {
    var presentingAlert: UIAlertController?
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var purchaseButton: UIButton!
    @IBOutlet weak var backButton: UIButton!
    
    
    let purchase = PublishRelay<GoodsItem>()
    private let bag = DisposeBag()
    var product: GoodsItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.image = product.image
        label.text = product.debugDescription
        
        purchaseButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.showAlert(message: NSLocalizedString("Buy_This_Product"),
                           action1: NSLocalizedString("Cancel"),
                           action2: NSLocalizedString("Confirm")) { [unowned self] (_) in
                            self.purchase.accept(self.product)
            }
        }).disposed(by: bag)
        
        backButton.rx.tap.subscribe(onNext: { [unowned self] in
            self.navigationController?.popViewController(animated: true)
        }).disposed(by: bag)
    }
}
