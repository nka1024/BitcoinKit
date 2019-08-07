//
//  BitcoinComUtxoProvider.swift
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

final public class BitcoinComUtxoProvider: UtxoProvider {
    private let endpoint: BitcoinComEndPoint
    private let dataStore: BitcoinKitDataStoreProtocol
    public init(network: Network, dataStore: BitcoinKitDataStoreProtocol) {
        self.endpoint = BitcoinComEndPoint(network: network)
        self.dataStore = dataStore
    }

    // GET API: reload utxos
    public func reload(address: Address, completion: (([UnspentTransaction]) -> Void)?) {
        let url = endpoint.getUtxoURL(with: address)
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data else {
                print("data is nil.")
                completion?([])
                return
            }
            guard let response = try? JSONDecoder().decode(BitcoinComUtxoResponseModel.self, from: data) else {
                print("decode failed.")
                completion?([])
                return
            }
            self?.dataStore.setData(data, forKey: .utxos)
            completion?(response.utxos.asUtxos(response.scriptPubKey))
        }
        task.resume()
    }

    // List utxos
    public var cached: [UnspentTransaction] {
        guard let data = dataStore.getData(forKey: .utxos) else {
            print("data is  nil")
            return []
        }

        guard let response = try? JSONDecoder().decode(BitcoinComUtxoResponseModel.self, from: data) else {
            print("data cannot be decoded to response")
            return []
        }
        return response.utxos.asUtxos(response.scriptPubKey)
    }
}

private extension Sequence where Element == BitcoinComUtxoModel {
    func asUtxos(_ scriptPubKey: String) -> [UnspentTransaction] {
        return compactMap { $0.asUtxo(scriptPubKey) }
    }
}

private struct BitcoinComUtxoResponseModel: Codable {
    let legacyAddress: String
    let cashAddress: String
    let scriptPubKey: String
    let slpAddress: String
    let utxos: [BitcoinComUtxoModel]
}

// MARK: - GET Unspent Transaction Outputs
private struct BitcoinComUtxoModel: Codable {
    let txid: String
    let vout: UInt32
    let amount: Decimal
    let satoshis: UInt64
    let height: Int?
    let confirmations: Int
    
    func asUtxo(_ scriptPubKey: String) -> UnspentTransaction? {
        guard let lockingScript = Data(hex: scriptPubKey), let txidData = Data(hex: String(txid)) else { return nil }
        let txHash: Data = Data(txidData.reversed())
        let output = TransactionOutput(value: satoshis, lockingScript: lockingScript)
        let outpoint = TransactionOutPoint(hash: txHash, index: vout)
        return UnspentTransaction(output: output, outpoint: outpoint)
    }
}

//{
//    "utxos": [
//    {
//    "txid": "36905521ab14eabc0c480f474325c813639a8ce003b399bf44af922cf59ba0d9",
//    "vout": 3,
//    "amount": 0.049,
//    "satoshis": 4900000,
//    "height": 594728,
//    "confirmations": 9
//    }
//    ],
//    "legacyAddress": "1oTXDesnKKGsxdEVpx74ddpnPRY3Ngro1",
//    "cashAddress": "bitcoincash:qqyvj3w69mpmjr8592h36zct4nj3nllwhvag7hqvyn",
//    "slpAddress": "simpleledger:qqyvj3w69mpmjr8592h36zct4nj3nllwhv3n4v4v6d",
//    "scriptPubKey": "76a91408c945da2ec3b90cf42aaf1d0b0bace519ffeebb88ac"
//}
