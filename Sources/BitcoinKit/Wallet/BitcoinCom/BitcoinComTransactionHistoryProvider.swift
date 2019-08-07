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

final public class BitcoinComTransactionHistoryProvider: TransactionHistoryProvider {
    private let endpoint: BitcoinComEndPoint
    private let dataStore: BitcoinKitDataStoreProtocol
    public init(network: Network, dataStore: BitcoinKitDataStoreProtocol) {
        self.endpoint = BitcoinComEndPoint(network: network)
        self.dataStore = dataStore
    }

    // Reload transactions [GET API]
    public func reload(address: Address, completion: (([BitcoinKitTransaction]) -> Void)?) {
        let url = endpoint.getTransactionHistoryURL(with: address)
        print(url)
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, res, err in
            guard let data = data else {
                completion?([])
                print("data = nil in BitcoinComTransactionResponse")
                return
            }
            do  {
                let response = try JSONDecoder().decode(BitcoinComTransactionResponse.self, from: data)
            } catch {
                print(error);
            }
            guard let response = try? JSONDecoder().decode(BitcoinComTransactionResponse.self, from: data) else {
                print("failed to decode BitcoinComTransactionResponse")
                completion?([])
                return
            }
            self?.dataStore.setData(data, forKey: .transactions)
            completion?(response.txs.asBTCTransactions(address: response.legacyAddress))
        }
        
        task.resume()
    }
    
    
    public func reload(address: Address, completion: (([Transaction]) -> Void)?) {
        let url = endpoint.getTransactionHistoryURL(with: address)
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data else {
                print("data = nil in BitcoinComTransactionResponse")
                completion?([])
                return
            }
            guard let response = try? JSONDecoder().decode(BitcoinComTransactionResponse.self, from: data) else {
                print("failed to decode BitcoinComTransactionResponse")
                completion?([])
                return
            }
            self?.dataStore.setData(data, forKey: .transactions)
            completion?(response.txs.asTransactions())
        }

        task.resume()
    }

    public var cached: [BitcoinKitTransaction] {
        guard let data = dataStore.getData(forKey: .transactions) else {
            print("data is  nil")
            return []
        }
        
        guard let response = try? JSONDecoder().decode(BitcoinComTransactionResponse.self, from: data) else {
            print("data cannot be decoded to BitcoinComTransactionResponse")
            return []
        }
        return response.txs.asBTCTransactions(address: response.legacyAddress)
        
    }
    
    // List cached transactions
    private var cachedTx: [Transaction] {
        guard let data = dataStore.getData(forKey: .transactions) else {
            print("data is  nil")
            return []
        }

        guard let response = try? JSONDecoder().decode([[BitcoinComTransaction]].self, from: data) else {
            print("data cannot be decoded to response")
            return []
        }
        return response.joined().asTransactions()
    }
}

private extension Sequence where Element == BitcoinComTransaction {
    func asTransactions() -> [Transaction] {
        return compactMap { $0.asTransaction() }
    }
    
    func asBTCTransactions(address: String) -> [BitcoinKitTransaction] {
        return compactMap { $0.asBTCTransaction(address: address) }
    }
}


private struct BitcoinComTransactionResponse: Codable {
    let pagesTotal: UInt32
    let currentPage: UInt32
    let legacyAddress: String
    let cashAddress: String
    let txs: [BitcoinComTransaction]
}

// MARK: - GET Transactions
private struct BitcoinComTransaction: Codable {
    let txid: String
    let version: UInt32
    let locktime: UInt32
    let vin: [TxIn]
    let vout: [TxOut]
    let blockhash: String
    let blockheight: Int
    let valueOut: Decimal
    let size: Int
    let valueIn: Decimal
    let fees: Decimal

    func asTransaction() -> Transaction? {
        var inputs: [TransactionInput] = []
        var outputs: [TransactionOutput] = []
        for txin in vin {
            guard let input = txin.asTransactionInput() else { return nil }
            inputs.append(input)
        }
        for txout in vout {
            guard let output = txout.asTransactionOutput() else { return nil }
            outputs.append(output)
        }
        return Transaction(version: version, inputs: inputs, outputs: outputs, lockTime: locktime)
    }
    
    func asBTCTransaction(address: String) -> BitcoinKitTransaction? {
        // positive
        var positive = true
        for input in vin {
            if address == input.addr{
                positive = false
                break
            }
        }
        
        
        // value
        var value = UInt64(0)
        if positive {
            var v = UInt64(0)
            for out in vout {
                for addr in out.scriptPubKey.addresses {
                    if addr == address {
                        v += UInt64((Double(out.value) ?? 0) * 100_000_000)
//                        break
                    }
                }
            }
            value = v
        } else {
            var v = UInt64(0)
            for inp in vin {
                if inp.addr != address {
                    v += UInt64((Double(inp.value) ?? 0) * 100_000_000)
                }
            }
            value = v
        }
        return BitcoinKitTransaction(timestamp: "",
                                     positive: positive,
                                     hash: txid,
                                     from: "",
                                     to: "",
                                     value: value,
                                     input: "",
                                     contract: "",
                                     tokenSymbol: "",
                                     confirmations: 0)
    }
}

private struct TxIn: Codable {
    let txid: String
    let vout: UInt32
    let sequence: UInt32
    let scriptSig: ScriptSig
    let addr: String
    // let valueSat: UInt64
     let value: Double

    // let n: Int
    // let doubleSpentTxID: String?

    func asTransactionInput() -> TransactionInput? {
        guard let signatureScript = Data(hex: scriptSig.hex), let txidData = Data(hex: String(txid)) else { return nil }
        let txHash: Data = Data(txidData.reversed())
        let outpoint = TransactionOutPoint(hash: txHash, index: vout)
        return TransactionInput(previousOutput: outpoint, signatureScript: signatureScript, sequence: sequence)
    }
}

private struct ScriptSig: Codable {
    let hex: String
    // let asm: String
}

private struct TxOut: Codable {
    let value: String
    let scriptPubKey: ScriptPubKey

    // let type: String
    // let n: Int
    // let spentTxId: String?
    // let spentIndex: Int?
    // let spentHeight: Int?

    func asTransactionOutput() -> TransactionOutput? {
        guard let lockingScript = Data(hex: scriptPubKey.hex) else { return nil }
        let int64Value: UInt64 = UInt64(((Double(value) ?? 0) * 100_000_000))
        return TransactionOutput(value: int64Value, lockingScript: lockingScript)
    }
}

private struct ScriptPubKey: Codable {
    let hex: String
    // let asm: String
     let addresses: [String]
}

//private extension Decimal {
//    var doubleValue: Double {
//        return NSDecimalNumber(decimal: self).doubleValue
//    }
//}
