//
//  BlockhainInfoRates.swift
//  BitcoinKit
//
//  Created by nka1024 on 29/07/2019.
//  Copyright © 2019 BitcoinKit developers. All rights reserved.
//

import Foundation

final public class BlockchainRatesProvider {
    
    private let dataStore: BitcoinKitDataStoreProtocol

    public var rateUSD: Double {
        if let cached = dataStore.getString(forKey: "rateUSD") {
            return Double(cached) ?? 0
        }
        else {
            return 0
        }
    }
    
    
    public var rateBCH: Double {
        if let cached = dataStore.getString(forKey: "rateBCH") {
            return Double(cached) ?? 0
        }
        else {
            return 0
        }
    }
    
    public init(dataStore: BitcoinKitDataStoreProtocol) {
        self.dataStore = dataStore
    }
    
    // GET API: reload balance
    public func reload(address: Address, completion: ((Double) -> Void)?) {
        reloadBCH(address: address, completion: completion);
        let url = URL(string: "https://blockchain.info/ticker")
        
        let task = URLSession.shared.dataTask(with: url!) { [weak self] data, _, _ in
            guard let data = data else {
                print("data is nil.")
                completion?(0)
                return
            }
            
            var r2: BlockchainRatesResponse? = nil
            do {
                r2 = try JSONDecoder().decode(BlockchainRatesResponse.self, from: data)
            } catch {
                print("error: \(error)")
                completion?(0)
                return
            }
            
            if let r2 = r2 {
                self?.dataStore.setString(String(r2.USD.average), forKey: "rateUSD")
                completion?(self?.rateUSD ?? 0)
            }
        }
        task.resume()
    }
    
//    eth: '1027',
//    eos: '1765',
//    pha: '3513',
//    btc: '1',
//    neo: '1376',
//    bch: '1831'
    public func reloadBCH(address: Address, completion: ((Double) -> Void)?) {
        let url = URL(string: "https://api.coinmarketcap.com/v2/ticker/1831/")
        
        let task = URLSession.shared.dataTask(with: url!) { [weak self] data, req, err in
            guard let data = data else {
                print("data is nil.")
                completion?(0)
                return
            }
            
            var r2: CoinmarketResponseModel? = nil
            do {
                r2 = try JSONDecoder().decode(CoinmarketResponseModel.self, from: data)
            } catch {
                print("error: \(error)")
                completion?(0)
                return
            }
            
            if let r2 = r2 {
                self?.dataStore.setString(String(r2.data.quotes.USD.price), forKey: "rateBCH")
                completion?(self?.rateUSD ?? 0)
            }
        }
        task.resume()
    }
}


private struct CoinmarketResponseModel: Codable {
    let data: CoinmarketDataModel
}

private struct CoinmarketDataModel: Codable {
    let quotes: CoinmarketQuotesModel
}

private struct CoinmarketQuotesModel: Codable {
    let USD: CoinmarketUSDModel
}

private struct CoinmarketUSDModel: Codable {
    let price: Double
}




//{
//    "attention": "WARNING: This API is now deprecated and will be taken offline soon.  Please switch to the new CoinMarketCap API to avoid interruptions in service. (https://pro.coinmarketcap.com/migrate/)",
//    "data": {
//        "id": 1831,
//        "name": "Bitcoin Cash",
//        "symbol": "BCH",
//        "website_slug": "bitcoin-cash",
//        "rank": 4,
//        "circulating_supply": 17937975.0,
//        "total_supply": 17937975.0,
//        "max_supply": 21000000.0,
//        "quotes": {
//            "USD": {
//                "price": 313.232039743,
//                "volume_24h": 1346286403.13463,
//                "market_cap": 5618748498.0,
//                "percent_change_1h": -0.8,
//                "percent_change_24h": -5.06,
//                "percent_change_7d": -3.98
//            }
//        },
//        "last_updated": 1565371507
//    },
//    "metadata": {
//        "timestamp": 1565371229,
//        "warning": "WARNING: This API is now deprecated and will be taken offline soon.  Please switch to the new CoinMarketCap API to avoid interruptions in service. (https://pro.coinmarketcap.com/migrate/)",
//        "error": null
//    }
//}

// MARK: - GET Unspent Transaction Outputs
private struct BlockchainRatesResponse: Codable {
    
    let USD: BlockchainUSDRate
    
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        USD = try container.decode(BlockchainUSDRate.self, forKey: .USD)
    }
    
}

private struct BlockchainUSDRate: Codable {
    
    let average: Double
    let last: Double
    let buy: Double
    let sell: Double
    let symbol: String
    enum CodingKeys: String, CodingKey {
        case average = "15m"
        case last, buy, sell, symbol
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        average = try container.decode(Double.self, forKey: .average)
        last = try container.decode(Double.self, forKey: .last)
        buy = try container.decode(Double.self, forKey: .buy)
        sell = try container.decode(Double.self, forKey: .sell)
        symbol = try container.decode(String.self, forKey: .symbol)
        
    }
    
}

// "USD" : {"15m" : 478.68, "last" : 478.68, "buy" : 478.55, "sell" : 478.68,  "symbol" : "$"},
