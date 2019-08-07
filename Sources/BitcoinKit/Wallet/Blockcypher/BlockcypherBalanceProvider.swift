//
//  BitcoinComBalanceProvider.swift
//  BitcoinKit
//
//  Created by nka1024 on 23/07/2019.
//  Copyright © 2019 BitcoinKit developers. All rights reserved.
//

import Foundation

final public class BlockcypherBalanceProvider: BalanceProvider {
    private let endpoint: BlockcypherEndPoint
    private let dataStore: BitcoinKitDataStoreProtocol
    
    public var balance: UInt64 {
        if let cached = dataStore.getString(forKey: "balance") {
            return UInt64(cached)!
        }
        else {
            return 0
        }
    }
    
    public init(network: Network, dataStore: BitcoinKitDataStoreProtocol) {
        self.endpoint = BlockcypherEndPoint(network: network)
        self.dataStore = dataStore
    }
    
    // GET API: reload balance
    public func reload(address: Address, completion: ((UInt64) -> Void)?) {
        let url = endpoint.getBalanceURL(with: address)
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data else {
                print("data is nil.")
                completion?(0)
                return
            }
            
            var r2: BlockcypherAddressModel? = nil
            do {
                r2 = try JSONDecoder().decode(BlockcypherAddressModel.self, from: data)
                //                r2 = try JSONDecoder().decode(BitcoinComAddressModel.self, from: d2!)
            } catch {
                print("error: \(error)")
                completion?(0)
                return
            }
            
            if let r2 = r2 {
                self?.dataStore.setString(String(r2.balance), forKey: "balance")
                completion?(r2.balance)
            }
        }
        task.resume()
    }
}

// MARK: - GET Unspent Transaction Outputs
private struct BlockcypherAddressModel: Codable {
    
    let address: String
    let balance: UInt64
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        address = try container.decode(String.self, forKey: .address)
        balance = try container.decode(UInt64.self, forKey: .balance)
    }
    
}
