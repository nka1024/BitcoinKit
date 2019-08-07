//
//  BitcoinComTransactionHistoryProvider.swift
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

final public class BlockcypherTransactionHistoryProvider: TransactionHistoryProvider {
    private let endpoint: BlockcypherEndPoint
    private let dataStore: BitcoinKitDataStoreProtocol
    public init(network: Network, dataStore: BitcoinKitDataStoreProtocol) {
        self.endpoint = BlockcypherEndPoint(network: network)
        self.dataStore = dataStore
    }

    // Reload transactions [GET API]
    public func reload(address: Address, completion: (([BitcoinKitTransaction]) -> Void)?) {
        let url = endpoint.getTransactionHistoryURL(with: address)
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data else {
                completion?([])
                return
            }
            do {
                let r = try JSONDecoder().decode(BitcoinComAddressModel.self, from: data)
            } catch {
                print(error);
            }
            guard let response = try? JSONDecoder().decode(BitcoinComAddressModel.self, from: data) else {
                completion?([])
                return
            }
            self?.dataStore.setData(data, forKey: .transactions)
            completion?(response.asBTCTransactions())
        }

        task.resume()
    }

    // List cached transactions
    public var cached: [BitcoinKitTransaction] {
        guard let data = dataStore.getData(forKey: .transactions) else {
            print("data is  nil")
            return []
        }

        guard let response = try? JSONDecoder().decode(BitcoinComAddressModel.self, from: data) else {
            print("data cannot be decoded to response")
            return []
        }
        
        return response.asBTCTransactions()
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
    
    func asBTCTransactions() -> [BitcoinKitTransaction] {
        var result = [BitcoinKitTransaction]()
        for tx in txs {
            var btctx = BitcoinKitTransaction()
            btctx.timestamp = tx.received ?? ""
            
            btctx.positive = true
            for input in tx.inputs {
                for addr in input.addresses {
                    if addr == address {
                        btctx.positive = false
                        break
                    }
                }
            }
            
            btctx.confirmations = UInt64(tx.confirmations ?? 0)
            btctx.hash = tx.hash ?? ""
            for inpt in tx.inputs {
                if let from = inpt.addresses.first {
                    btctx.from = from
                }
            }
            
            for outpt in tx.outputs {
                if let to = outpt.addresses.first {
                    btctx.to = to
                }
            }
            
            if btctx.positive {
                var value = UInt64(0)
                for out in tx.outputs {
                    for addr in out.addresses {
                        if addr == address {
                            value += UInt64(out.value)
                            break
                        }
                    }
                }
                btctx.value = value
            } else {
                var value = UInt64(0)
                for outp in tx.outputs {
                    for addr in outp.addresses {
                        if addr != address {
                            value += UInt64(outp.value)
                            break
                        }
                    }
                }
                btctx.value = value
            }
            btctx.tokenSymbol = "BTC"
            
            result.append(btctx)
        }
        return result
    }
    
    func asTransactions() -> [Transaction] {
        var result = [Transaction]()
        
        for tx in txs {
            if let lockTime = tx.lock_time {
                var inputs = [TransactionInput]()
                var outputs = [TransactionOutput]()
                for txin in tx.inputs {
                    if let script = txin.script {
                        let outPoint = TransactionOutPoint(hash: txin.prev_hash.data(using: .utf8)!, index: UInt32(txin.output_index))
                        let input = TransactionInput(previousOutput: outPoint, signatureScript: script.data(using: .utf8)!, sequence: UInt32(txin.sequence))
                        inputs.append(input)
                    }
                }
                for txout in tx.outputs {
                    if let script = txout.script {
                        let output = TransactionOutput(value: UInt64(txout.value), lockingScript: script.data(using: .utf8)!);
                    outputs.append(output)
                    }
                }
                
                result.append(Transaction(version: UInt32(tx.ver ?? 1), inputs: inputs, outputs: outputs, lockTime: UInt32(lockTime)))
            }
            
        }
//        print ("txs: \(txs.count); transactions: \(result.count)")

        return result
    }
}

private struct BitcoinComTxModel: Codable {
    let block_hash: String?
    let block_height: Int?
    let hash: String?
    let addresses: [String]?
    let total: Int?
    let fees: Int?
    let size: Int?
    let preference: String?
    let relayed_by: String?
    let confirmed: String? // Date
    let received: String? // Date
    let ver: Int?
    let lock_time: Int?
    let double_spend: Bool?
    let vin_sz: Int?
    let vout_sz: Int?
    let confirmations: Int?
    let confidence: Int?
    let inputs: [BitcointComTxInputModel]
    let outputs: [BitcointComTxOutputModel]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        block_hash = try? container.decode(String.self, forKey: .block_hash)
        block_height = try? container.decode(Int.self, forKey: .block_height)
        hash = try? container.decode(String.self, forKey: .hash)
        addresses = try? container.decode([String].self, forKey: .addresses)
        total = try? container.decode(Int.self, forKey: .total)
        fees = try? container.decode(Int.self, forKey: .fees)
        size = try? container.decode(Int.self, forKey: .size)
        preference = try? container.decode(String.self, forKey: .preference)
        relayed_by = try? container.decode(String.self, forKey: .relayed_by)
        confirmed = try? container.decode(String.self, forKey: .confirmed)
        received = try container.decode(String.self, forKey: .received)
        ver = try? container.decode(Int.self, forKey: .ver)
        lock_time = try? container.decode(Int.self, forKey: .lock_time)
        double_spend = try? container.decode(Bool.self, forKey: .double_spend)
        vin_sz = try? container.decode(Int.self, forKey: .vin_sz)
        vout_sz = try? container.decode(Int.self, forKey: .vout_sz)
        confirmations = try? container.decode(Int.self, forKey: .confirmations)
        confidence = try? container.decode(Int.self, forKey: .confidence)
        
        inputs = try container.decode([BitcointComTxInputModel].self, forKey: .inputs);
        outputs = try container.decode([BitcointComTxOutputModel].self, forKey: .outputs);
    }
}

private struct BitcointComTxInputModel: Codable {
    let prev_hash: String
    let output_index: Int
    let script: String?
    let output_value: Int
    let sequence: Int
    let addresses: [String]
    let script_type: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        prev_hash = try container.decode(String.self, forKey: .prev_hash)
        output_index = try container.decode(Int.self, forKey: .output_index)
        script = try? container.decode(String.self, forKey: .script)
        output_value = try container.decode(Int.self, forKey: .output_value)
        sequence = try container.decode(Int.self, forKey: .sequence)
        if let addresses = try? container.decode([String].self, forKey: .addresses) {
            self.addresses = addresses
        } else {
            addresses = []
        }
        script_type = try container.decode(String.self, forKey: .script_type)
    }
}

private struct BitcointComTxOutputModel: Codable {
    let value: Int
    let script: String?
    let addresses: [String]
    let script_type: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        value = try container.decode(Int.self, forKey: .value)
        script = try? container.decode(String.self, forKey: .script)
        if let addresses = try? container.decode([String].self, forKey: .addresses) {
            self.addresses = addresses
        } else {
            addresses = []
        }
        script_type = try container.decode(String.self, forKey: .script_type)
    }
}

// MARK: - GET Transactions
//private struct BitcoinComTransaction: Codable {
//    let txid: String
//    let version: UInt32
//    let locktime: UInt32
//    let vin: [TxIn]
//    let vout: [TxOut]
//    let blockhash: String
//    let blockheight: Int
//    let valueOut: Decimal
//    let size: Int
//    let valueIn: Decimal
//    let fees: Decimal
//
//    func asTransaction() -> Transaction? {
//        var inputs: [TransactionInput] = []
//        var outputs: [TransactionOutput] = []
//        for txin in vin {
//            guard let input = txin.asTransactionInput() else { return nil }
//            inputs.append(input)
//        }
//        for txout in vout {
//            guard let output = txout.asTransactionOutput() else { return nil }
//            outputs.append(output)
//        }
//        return Transaction(version: version, inputs: inputs, outputs: outputs, lockTime: locktime)
//    }
//}
//
//private struct TxIn: Codable {
//    let txid: String
//    let vout: UInt32
//    let sequence: UInt32
//    let scriptSig: ScriptSig
//    // let addr: String
//    // let valueSat: UInt64
//    // let value: Decimal
//
//    // let n: Int
//    // let doubleSpentTxID: String?
//
//    func asTransactionInput() -> TransactionInput? {
//        guard let signatureScript = Data(hex: scriptSig.hex), let txidData = Data(hex: String(txid)) else { return nil }
//        let txHash: Data = Data(txidData.reversed())
//        let outpoint = TransactionOutPoint(hash: txHash, index: vout)
//        return TransactionInput(previousOutput: outpoint, signatureScript: signatureScript, sequence: sequence)
//    }
//}
//
//private struct ScriptSig: Codable {
//    let hex: String
//    // let asm: String
//}
//
//private struct TxOut: Codable {
//    let value: Decimal
//    let scriptPubKey: ScriptPubKey
//
//    // let type: String
//    // let n: Int
//    // let spentTxId: String?
//    // let spentIndex: Int?
//    // let spentHeight: Int?
//
//    func asTransactionOutput() -> TransactionOutput? {
//        guard let lockingScript = Data(hex: scriptPubKey.hex) else { return nil }
//        let int64Value: UInt64 = UInt64((value * 100_000_000).doubleValue)
//        return TransactionOutput(value: int64Value, lockingScript: lockingScript)
//    }
//}
//
//private struct ScriptPubKey: Codable {
//    let hex: String
//    // let asm: String
//    // let addresses: [String]
//}
//
//private extension Decimal {
//    var doubleValue: Double {
//        return NSDecimalNumber(decimal: self).doubleValue
//    }
//}
