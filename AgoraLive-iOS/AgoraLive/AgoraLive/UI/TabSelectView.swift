//
//  TabSelectView.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/2/19.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit
import RxSwift
import RxRelay

class TabSelectView: UIScrollView {
    struct TitleProperty {
        var color: UIColor
        var font: UIFont
    }
    
    private lazy var underline: CALayer = {
        let line = CALayer()
        line.backgroundColor = underlineColor.cgColor
        return line
    }()
    
    private var titles: [String]?
    private var titleButtons: [UIButton]?
    
    private let bag = DisposeBag()
    
    var selectedIndex = BehaviorRelay(value: 0) {
        didSet {
            updateSelectedButton(selectedIndex.value)
            updateUnderlinePosition()
        }
    }
    
    var underlineColor: UIColor = UIColor(hexString: "#0088EB") {
        didSet {
            underline.backgroundColor = underlineColor.cgColor
        }
    }
    
    var unselectedTitle = TitleProperty(color: UIColor.gray,
                                        font: UIFont.systemFont(ofSize: 14))
    
    var selectedTitle = TitleProperty(color: UIColor.black,
                                      font: UIFont.systemFont(ofSize: 16, weight: .medium))
    
    var titleSpace: CGFloat = 28.0
    var underlineWidth: CGFloat? = nil
    var underlineHeight: CGFloat = 5
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.layer.masksToBounds = true
        self.showsHorizontalScrollIndicator = false
        self.showsVerticalScrollIndicator = false
    }
}

extension TabSelectView {
    func update(_ titles: [String]) {
        guard titles.count > 0 else {
            return
        }
        
        if let buttons = self.titleButtons {
            for item in buttons {
                item.removeFromSuperview()
            }
            self.titleButtons = nil
        }
        
        self.titles = titles
        
        layoutButtons(titles: titles, space: titleSpace)
        selectedIndex.accept(0)
        
        selectedIndex.asObservable().subscribe(onNext: { [unowned self] (index) in
            self.updateSelectedButton(index)
            self.updateUnderlinePosition()
        }).disposed(by: bag)
    }
}

private extension TabSelectView {
    func layoutButtons(titles: [String], space: CGFloat) {
        var lastButtonMaxX: CGFloat?
        var buttons = [UIButton]()
        
        for (index, title) in titles.enumerated() {
            let textSize = title.size(font: selectedTitle.font,
                                      drawRange: CGSize(width: CGFloat(MAXFLOAT), height: bounds.height))
            
            let button = UIButton(frame: CGRect(x: lastButtonMaxX ?? 0,
                                                y: 0,
                                                width: textSize.width,
                                                height: textSize.height))
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = unselectedTitle.font
            button.tag = index
            button.setTitleColor(unselectedTitle.color, for: .normal)
            buttons.append(button)
            self.addSubview(button)
            lastButtonMaxX = button.frame.maxX + space
            
            button.rx.tap.subscribe(onNext: { [weak button, weak self] (event) in
                guard let tButton = button,
                    let strongSelf = self else {
                        return
                }
                strongSelf.selectedIndex.accept(tButton.tag)
                
                let offsetX = tButton.frame.maxX - strongSelf.frame.width
                let offset = CGPoint(x: offsetX > 0 ? offsetX : 0,
                                     y: 0)
                strongSelf.setContentOffset(offset, animated: true)
            }).disposed(by: bag)
        }
        
        self.contentSize = CGSize(width: buttons.last!.frame.maxX,
                                  height: 0)
        self.titleButtons = buttons
    }
    
    func updateSelectedButton(_ index: Int) {
        guard let buttons = self.titleButtons else {
            assert(false, "buttons nil")
            return
        }
        
        for (i, item) in buttons.enumerated() {
            if i == index {
                item.titleLabel?.font = selectedTitle.font
                item.setTitleColor(selectedTitle.color, for: .normal)
            } else {
                item.titleLabel?.font = unselectedTitle.font
                item.setTitleColor(unselectedTitle.color, for: .normal)
            }
        }
    }
    
    func updateUnderlinePosition() {
        guard let buttons = self.titleButtons else {
            assert(false, "buttons nil")
            return
        }
        self.layer.insertSublayer(underline, at: 0)
        let index = selectedIndex.value
        
        let h: CGFloat = underlineHeight
    
        var x: CGFloat
        var w: CGFloat
        
        if let tW = underlineWidth {
            x = (buttons[index].frame.width - tW) * 0.5 + buttons[index].frame.minX
            w = tW
        } else {
            x = buttons[index].frame.minX
            w = buttons[index].frame.width
        }
        
        let boundsWidth = UIScreen.main.bounds.width - 30
        let y = bounds.height - h
        
        var offsetX: CGFloat = (x + w) - boundsWidth
        offsetX = offsetX >= 0 ? offsetX : 0
        
        if self.contentOffset.x < offsetX {
            self.setContentOffset(CGPoint(x: offsetX, y: 0), animated: true)
        }
        
        UIView.animate(withDuration: 0.3) { [unowned self] in
            self.underline.frame = CGRect(x: x,
                                          y: y,
                                          width: w,
                                          height: h)
        }
    }
}
