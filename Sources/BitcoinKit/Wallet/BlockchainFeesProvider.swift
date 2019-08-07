//
//  BlockhainInfoRates.swift
//  BitcoinKit
//
//  Created by nka1024 on 29/07/2019.
//  Copyright © 2019 BitcoinKit developers. All rights reserved.
//

import Foundation

final public class BlockchainFeesProvider {
    
    private let dataStore: BitcoinKitDataStoreProtocol
    
    public var feesBTC: (UInt64, UInt64, UInt64) {
        if let cached = dataStore.getData(forKey: "feeBTC") {
            do {
                let r2 = try JSONDecoder().decode(BlockchainFeesResponse.self, from: cached)
                return (r2.fastestFee, r2.halfHourFee, r2.hourFee)
            } catch {
                print("error parsing fees cache: \(error)")
            }
        }
        return (0, 0, 0)
    }
    
    public init(dataStore: BitcoinKitDataStoreProtocol) {
        self.dataStore = dataStore
    }
    
    // GET API: reload balance
    public func reload(completion: ((UInt64, UInt64, UInt64) -> Void)?) {
        let url = URL(string: "https://bitcoinfees.earn.com/api/v1/fees/recommended")
        
        let task = URLSession.shared.dataTask(with: url!) { [weak self] data, _, _ in
            guard let data = data else {
                print("data is nil.")
                completion?(0, 0, 0)
                return
            }
            
            var r2: BlockchainFeesResponse? = nil
            do {
                r2 = try JSONDecoder().decode(BlockchainFeesResponse.self, from: data)
            } catch {
                print("error parsing fees response: \(error)")
                completion?(0, 0, 0)
                return
            }
            
            if let r2 = r2 {
                self?.dataStore.setData(data, forKey: "feeBTC")
                completion?(r2.fastestFee, r2.halfHourFee, r2.hourFee)
            }
        }
        task.resume()
    }
}

private struct BlockchainFeesResponse: Codable {
    let fastestFee: UInt64
    let halfHourFee: UInt64
    let hourFee: UInt64
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fastestFee = try container.decode(UInt64.self, forKey: .fastestFee)
        halfHourFee = try container.decode(UInt64.self, forKey: .halfHourFee)
        hourFee = try container.decode(UInt64.self, forKey: .hourFee)
    }
    
}
