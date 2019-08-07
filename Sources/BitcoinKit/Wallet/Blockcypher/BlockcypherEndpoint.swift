//
//  BitcoinComEndpoint.swift
//
//  Copyright © 2018 BitcoinKit developers
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

public struct BlockcypherEndPoint {
    
    private let baseUrl: String

    init(network: Network) {
        switch network {
        case .mainnet:
            self.baseUrl = "https://api.blockcypher.com/v1/btc/main/"
        case .testnet:
            self.baseUrl = "https://api.blockcypher.com/v1/btc/test3/"
        default:
            fatalError("Bitcoin.com API is only available for Bitcoin Cash.")
        }
    }

    public func getUtxoURL(with address: Address) -> URL {
        let parameter: String = "\(address.base58)"
        let url = baseUrl + "addrs/\(parameter)/full"
        return BlockcypherEndPoint.convert(string: url)!
    }

    public func getBalanceURL(with address: Address) -> URL {
        let parameter: String = "\(address.base58)"
        let url = baseUrl + "addrs/\(parameter)/?unspentOnly=true"
        return BlockcypherEndPoint.convert(string: url)!
    }
    
    public func getTransactionHistoryURL(with address: Address) -> URL {
        let parameter: String = "\(address.base58)"
        let url = baseUrl + "addrs/\(parameter)/full?txlimit=100"
        return BlockcypherEndPoint.convert(string: url)!
    }

    public func postRawtxURL(rawtx: String) -> URL {
        let url = baseUrl + "txs/push"
        return BlockcypherEndPoint.convert(string: url)!
    }
    
    public func postTxNew1() -> URL {
        let url = baseUrl + "txs/new"
        return BlockcypherEndPoint.convert(string: url)!
    }
    
    public func postTxSend1() -> URL {
        let url = baseUrl + "txs/send"
        return BlockcypherEndPoint.convert(string: url)!
    }
    
    public static func convert(string: String) -> URL? {
        guard let encoded = string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: encoded)
    }

}

enum BlockcypherApiInitializationError: Error {
    case invalidNetwork
}
