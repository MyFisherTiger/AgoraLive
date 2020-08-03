//
//  ShppoingSmallRenderView.swift
//  AgoraLive
//
//  Created by CavanSu on 2020/7/30.
//  Copyright © 2020 Agora. All rights reserved.
//

import UIKit

class ShppoingSmallRenderView: UIView {
    private let shadow = UIImageView()
    
    let nameLabel = UILabel()
    let renderView = UIView()
    let closeButton = UIButton()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let renderX: CGFloat = 10
        let renderY = renderX
        let renderWith: CGFloat = bounds.width - (renderX * CGFloat(2))
        let renderHeight: CGFloat = bounds.height - (renderY * CGFloat(2))
        renderView.frame = CGRect(x: renderX,
                                  y: renderY,
                                  width: renderWith,
                                  height: renderHeight)
        
        let shadowHeight: CGFloat = 28
        shadow.frame = CGRect(x: 0,
                              y: renderView.bounds.height - shadowHeight,
                              width: renderView.bounds.width,
                              height: shadowHeight)
        
        nameLabel.frame = shadow.frame
        
        let buttonWidth: CGFloat = 20
        let buttonHeight = buttonWidth
        let buttonX: CGFloat = bounds.width - buttonWidth
        let buttonY: CGFloat = 0
        closeButton.frame = CGRect(x: buttonX,
                                   y: buttonY,
                                   width: buttonWidth,
                                   height: buttonHeight)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initViews()
    }
    
    func initViews() {
        backgroundColor = .red
        
        addSubview(renderView)
        
        shadow.image = UIImage(named: "shadow")
        renderView.addSubview(shadow)
        
        nameLabel.textColor = .white
        nameLabel.font = UIFont.systemFont(ofSize: 11)
        renderView.addSubview(nameLabel)
        
        addSubview(closeButton)
    }
}
