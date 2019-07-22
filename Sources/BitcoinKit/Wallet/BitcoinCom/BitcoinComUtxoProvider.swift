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
    private let endpoint: ApiEndPoint.BitcoinCom
    private let dataStore: BitcoinKitDataStoreProtocol
    public init(network: Network, dataStore: BitcoinKitDataStoreProtocol) {
        self.endpoint = ApiEndPoint.BitcoinCom(network: network)
        self.dataStore = dataStore
    }

    // GET API: reload utxos
    public func reload(addresses: [Address], completion: (([UnspentTransaction]) -> Void)?) {
        let url = endpoint.getUtxoURL(with: addresses)
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data else {
                print("data is nil.")
                completion?([])
                return
            }
            
            do {
              try JSONDecoder().decode(BitcoinComAddressModel.self, from: data)
            } catch {
                print("error: \(error)")
                completion?([])
                return
            }
            
            guard let r2 = try? JSONDecoder().decode(BitcoinComAddressModel.self, from: data) else {
                print("decode failed.")
                completion?([])
                return
            }
            print ("address:\(r2.address)");
            print ("txs.count:\(r2.txs.count)");
            self?.dataStore.setData(data, forKey: .utxos)
            completion?(r2.asUtxos())
        }
        task.resume()
    }

    // List utxos
    public var cached: [UnspentTransaction] {
        guard let data = dataStore.getData(forKey: .utxos) else {
            print("cache data is  nil")
            return []
        }

        guard let r2 = try? JSONDecoder().decode(BitcoinComAddressModel.self, from: data) else {
            print("data cannot be decoded to response")
            return []
        }
        
        return r2.asUtxos()
    }
}

// MARK: - GET Unspent Transaction Outputs
private struct BitcoinComAddressModel: Codable {

    let address: String
    let balance: Int
    let total_received: Int
    let total_sent: Int
    let unconfirmed_balance: Int
    let final_balance: Int
    let n_tx: Int
    let unconfirmed_n_tx: Int
    let final_n_tx: Int
    
    let txs: [BitcoinComTxModel]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        address = try container.decode(String.self, forKey: .address)
        balance = try container.decode(Int.self, forKey: .balance)
        total_received = try container.decode(Int.self, forKey: .total_received)
        total_sent = try container.decode(Int.self, forKey: .total_sent)
        unconfirmed_balance = try container.decode(Int.self, forKey: .unconfirmed_balance)
        final_balance = try container.decode(Int.self, forKey: .final_balance)
        n_tx = try container.decode(Int.self, forKey: .n_tx)
        unconfirmed_n_tx = try container.decode(Int.self, forKey: .unconfirmed_n_tx)
        final_n_tx = try container.decode(Int.self, forKey: .final_n_tx)
    
        txs = try container.decode([BitcoinComTxModel].self, forKey: .txs);
    }
    
    func asUtxos() -> [UnspentTransaction] {
        var utxos = [UnspentTransaction]()
        
        for tx in txs {
            let scriptPubKey = tx.outputs.last?.script
            let txid = tx.hash
            var amount = UInt64(0)
            if let value = tx.outputs.last?.value {
                amount = UInt64(value)
            }
            let vout = UInt32(tx.vout_sz)
            if let lockingScript = Data(hex: scriptPubKey!), let txidData = Data(hex: String(txid)) {
                let txHash: Data = Data(txidData.reversed())
                let output = TransactionOutput(value: amount, lockingScript: lockingScript)
                let outpoint = TransactionOutPoint(hash: txHash, index: vout)
                utxos.append(UnspentTransaction(output: output, outpoint: outpoint))
            }

        }
        print ("txs: \(txs.count); utxos: \(utxos.count)")
//        TransactionOutput(
//        guard let lockingScript = Data(hex: scriptPubKey), let txidData = Data(hex: String(txid)) else { return nil }
//        let txHash: Data = Data(txidData.reversed())
//        let output = TransactionOutput(value: satoshis, lockingScript: lockingScript)
//        let outpoint = TransactionOutPoint(hash: txHash, index: vout)
//        return UnspentTransaction(output: output, outpoint: outpoint)
        return utxos
    }
}

private struct BitcoinComTxModel: Codable {
    let block_hash: String?
    let block_height: Int
    let hash: String
    let addresses: [String]
    let total: Int
    let fees: Int
    let size: Int
    let preference: String
    let relayed_by: String
    let confirmed: String // Date
    let received: String // Date
    let ver: Int
    let lock_time: Int
    let double_spend: Bool
    let vin_sz: Int
    let vout_sz: Int
    let confirmations: Int
    let confidence: Int
    let inputs: [BitcointComTxInputModel]
    let outputs: [BitcointComTxOutputModel]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        block_hash = try container.decode(String.self, forKey: .block_hash)
        block_height = try container.decode(Int.self, forKey: .block_height)
        hash = try container.decode(String.self, forKey: .hash)
        addresses = try container.decode([String].self, forKey: .addresses)
        total = try container.decode(Int.self, forKey: .total)
        fees = try container.decode(Int.self, forKey: .fees)
        size = try container.decode(Int.self, forKey: .size)
        preference = try container.decode(String.self, forKey: .preference)
        relayed_by = try container.decode(String.self, forKey: .relayed_by)
        confirmed = try container.decode(String.self, forKey: .confirmed)
        received = try container.decode(String.self, forKey: .received)
        ver = try container.decode(Int.self, forKey: .ver)
        lock_time = try container.decode(Int.self, forKey: .lock_time)
        double_spend = try container.decode(Bool.self, forKey: .double_spend)
        vin_sz = try container.decode(Int.self, forKey: .vin_sz)
        vout_sz = try container.decode(Int.self, forKey: .vout_sz)
        confirmations = try container.decode(Int.self, forKey: .confirmations)
        confidence = try container.decode(Int.self, forKey: .confidence)
        
        inputs = try container.decode([BitcointComTxInputModel].self, forKey: .inputs);
        outputs = try container.decode([BitcointComTxOutputModel].self, forKey: .outputs);
    }
}

private struct BitcointComTxInputModel: Codable {
    let prev_hash: String
    let output_index: Int
    let script: String
    let output_value: Int
    let sequence: Int
    let addresses: [String]
    let script_type: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        prev_hash = try container.decode(String.self, forKey: .prev_hash)
        output_index = try container.decode(Int.self, forKey: .output_index)
        script = try container.decode(String.self, forKey: .script)
        output_value = try container.decode(Int.self, forKey: .output_value)
        sequence = try container.decode(Int.self, forKey: .sequence)
        addresses = try container.decode([String].self, forKey: .addresses)
        script_type = try container.decode(String.self, forKey: .script_type)
    }
}

private struct BitcointComTxOutputModel: Codable {
    let value: Int
    let script: String
    let addresses: [String]
    let script_type: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        value = try container.decode(Int.self, forKey: .value)
        script = try container.decode(String.self, forKey: .script)
        addresses = try container.decode([String].self, forKey: .addresses)
        script_type = try container.decode(String.self, forKey: .script_type)
    }
}

//{
//    "block_hash": "0000000000000000af64802c79...",
//    "block_height": 292586,
//    "hash": "b4735a0690dab16b8789fceaf81c511f...",
//    "addresses": [
//        "18KXZzuC3xvz6upUMQpsZzXrBwNPWZjdSa",
//        "1AAuRETEcHDqL4VM3R97aZHP8DSUHxpkFV",
//        "1DEP8i3QJCsomS4BSMY2RpU1upv62aGvhD",
//        "1VxsEDjo6ZLMT99dpcLu4RQonMDVEQQTG"
//    ],
//    "total": 3537488,
//    "fees": 20000,
//    "size": 438,
//    "preference": "medium",
//    "relayed_by": "",
//    "confirmed": "2014-03-26T17:08:04Z",
//    "received": "2014-03-26T17:08:04Z",
//    "ver": 1,
//    "lock_time": 0,
//    "double_spend": false,
//    "vin_sz": 2,
//    "vout_sz": 2,
//    "confirmations": 64492,
//    "confidence": 1,
//    "inputs": [
//    {
//        "prev_hash": "729f6469b59fea5da7...",
//        "output_index": 0,
//        "script": "483045022100d06cdad1a...",
//        "output_value": 3500000,
//        "sequence": 4294967295,
//        "addresses": [
//            "1VxsEDjo6ZLMT99dpcLu4RQonMDVEQQTG"
//        ],
//        "script_type": "pay-to-pubkey-hash"
//        },
//        ...
//    ],
//    "outputs": [
//    {
//        "value": 3500000,
//        "script": "76a9148629647bd642a237...",
//        "addresses": [
//            "1DEP8i3QJCsomS4BSMY2RpU1upv62aGvhD"
//        ],
//        "script_type": "pay-to-pubkey-hash"
//    },
//    {
//        "value": 37488,
//        "script": "76a9145049e2ad94ed9c68...",
//        "spent_by": "3ebe4bb294beaed58aca83...",
//        "addresses": [
//            "18KXZzuC3xvz6upUMQpsZzXrBwNPWZjdSa"
//        ],
//            "script_type": "pay-to-pubkey-hash"
//        }
//    ]
//},
