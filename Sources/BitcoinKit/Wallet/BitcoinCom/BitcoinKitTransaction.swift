//
//  BitcoinKitTransaction.swift
//  BitcoinKit
//
//  Created by nka1024 on 24/07/2019.
//  Copyright © 2019 BitcoinKit developers. All rights reserved.
//

import Foundation

public struct BitcoinKitTransaction {
    public var timestamp: String = ""
    public var positive: Bool = false
    public var hash: String = ""
    public var from: String = ""
    public var to: String = ""
    public var value: UInt64 = 0
    public var input: String = ""
    public var contract: String = ""
    public var tokenSymbol: String = ""
}
