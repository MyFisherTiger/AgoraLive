//
//  TypeAlias.swift
//  AgoraPremium
//
//  Created by GongYuhua on 4/11/16.
//  Copyright © 2016 Agora. All rights reserved.
//

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif

//MARK: - Block
typealias DicCompletion = (([String: Any]) -> Void)?
typealias AnyCompletion = ((Any?) -> Void)?
typealias StringCompletion = ((String) -> Void)?
typealias IntCompletion = ((Int) -> Void)?
typealias Completion = (() -> Void)?

typealias DicEXCompletion = (([String: Any]) throws -> Void)?
typealias StringExCompletion = ((String) throws -> Void)?
typealias DataExCompletion = ((Data) throws -> Void)?

typealias ErrorCompletion = ((Error) -> Void)?
typealias ErrorBoolCompletion = ((Error) -> Bool)?

//MARK: - Dictinary
typealias StringAnyDic = [String: Any]

//MARK: - Image
#if os(iOS)
public typealias AGEImage = UIImage
#else
public typealias AGEImage = NSImage
#endif

//MARK: - View
#if os(iOS)
public typealias ALView = UIView
#else
public typealias ALView = NSView
#endif
