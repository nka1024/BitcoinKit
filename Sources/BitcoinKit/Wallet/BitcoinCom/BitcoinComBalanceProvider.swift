//
//  BitcoinComBalanceProvider.swift
//  BitcoinKit
//
//  Created by nka1024 on 23/07/2019.
//  Copyright © 2019 BitcoinKit developers. All rights reserved.
//

import Foundation

final public class BitcoinComBalanceProvider: BalanceProvider {
    private let dataStore: BitcoinKitDataStoreProtocol
    
    private let utxoProvider: BitcoinComUtxoProvider
    public var balance: UInt64 {
        if let cached = dataStore.getString(forKey: "balance") {
            return UInt64(cached)!
        }
        else {
            return 0
        }
    }
    
    public init(network: Network, dataStore: BitcoinKitDataStoreProtocol) {
        self.utxoProvider = BitcoinComUtxoProvider(network: network, dataStore: dataStore)
        self.dataStore = dataStore
    }
    
    // GET API: reload balance
    public func reload(address: Address, completion: ((UInt64) -> Void)?) {
        utxoProvider.reload(address: address, completion: { [weak self] (utxs) in
            if let balance = self?.utxoProvider.cached.sum() {
                self?.dataStore.setString(String(balance), forKey: "balance")
                completion?(balance)
            }
            
        })
    }
}
