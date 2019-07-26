//
//  Wallet.swift
//
//  Copyright © 2018 Kishikawa Katsumi
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

// Some of default parameters of Wallet class [utxoProvider, transactionHistoryProvider, transactionBroadcaster] are only compatible with Bitcoin Cash(BCH).
// They are using rest.bitcoin.com API endpoints and the endpoints are only available for Bitcoin Cash(BCH).
// If you want to use BTC, please implement
final public class Wallet {
    public let privateKey: PrivateKey
    public let publicKey: PublicKey
    public var address: Address { return publicKey.toCashaddr() }

    public let network: Network
    private let walletDataStore: BitcoinKitDataStoreProtocol
    private let addressProvider: AddressProvider
    private let utxoProvider: UtxoProvider
    private let transactionHistoryProvider: TransactionHistoryProvider
    private let transactionBroadcaster: TransactionBroadcaster
    private let utxoSelector: UtxoSelector
    private let transactionBuilder: TransactionBuilder
    private let transactionSigner: TransactionSigner
    private let balanceProvider: BitcoinComBalanceProvider
    
    public init(privateKey: PrivateKey,
                addressProvider: AddressProvider? = nil,
                utxoProvider: UtxoProvider? = nil,
                transactionHistoryProvider: TransactionHistoryProvider? = nil,
                transactionBroadcaster: TransactionBroadcaster? = nil,
                utxoSelector: UtxoSelector = StandardUtxoSelector(),
                transactionBuilder: TransactionBuilder = StandardTransactionBuilder(),
                transactionSigner: TransactionSigner = StandardTransactionSigner()) {
        let network = privateKey.network
        self.privateKey = privateKey
        self.publicKey = privateKey.publicKey()
        self.network = network

        let userDefaults: BitcoinKitDataStoreProtocol = UserDefaults.bitcoinKit(walletId: publicKey.data.hex)

        self.addressProvider = addressProvider
            ?? StandardAddressProvider(keys: [privateKey])
        self.utxoProvider = utxoProvider
            ?? BitcoinComUtxoProvider(network: network, dataStore: userDefaults)
        self.transactionHistoryProvider = transactionHistoryProvider
            ?? BitcoinComTransactionHistoryProvider(network: network, dataStore: userDefaults)
        self.transactionBroadcaster = transactionBroadcaster
            ?? BitcoinComTransactionBroadcaster(network: network)

        self.walletDataStore = userDefaults
        self.utxoSelector = utxoSelector
        self.transactionBuilder = transactionBuilder
        self.transactionSigner = transactionSigner
        self.balanceProvider = BitcoinComBalanceProvider(network: network, dataStore: userDefaults)
    }

    public convenience init?(wif: String) {
        guard let privateKey = try? PrivateKey(wif: wif) else {
            return nil
        }
        self.init(privateKey: privateKey)
    }

    public func save() {
        walletDataStore.setString(privateKey.toWIF(), forKey: .wif)
    }

    public func addresses() -> [Address] {
        let cache = addressProvider.list()
        guard !cache.isEmpty else {
            addressProvider.reload(keys: [privateKey], completion: nil)
            return [address]
        }
        return cache
    }

    public func reloadBalance(completion: ((UInt64) -> Void)? = nil) {
        balanceProvider.reload(address: address, completion: completion)
    }
    
//    public func reloadBalance(completion: (([UnspentTransaction]) -> Void)? = nil) {
//        utxoProvider.reload(addresses: addresses(), completion: completion)
//    }
    
    public func balance() -> UInt64 {
        return balanceProvider.balance
    }

    public func utxos() -> [UnspentTransaction] {
        return utxoProvider.cached
    }

    public func transactions() -> [BitcoinKitTransaction] {
        return transactionHistoryProvider.cached
    }

    public func reloadTransactions(completion: (([BitcoinKitTransaction]) -> Void)? = nil) {
        transactionHistoryProvider.reload(address: address, completion: completion)
    }

    public func send(to toAddress: Address, amount: UInt64, completion: ((_ txid: String?) -> Void)? = nil) throws {
        transactionBroadcaster.txNew1(to: toAddress, from: address, amount: amount, privateKey: privateKey, publicKey: publicKey) { (result) in
            DispatchQueue.main.async {
                completion?(result)
            }
            let address = 10;
            print(self.address);
        }
    }
    
    // before moving to BlockCypher api
    public func sendOld(to toAddress: Address, amount: UInt64, completion: ((_ txid: String?) -> Void)? = nil) throws {
//        let utxos = utxoProvider.cached
//        let (utxosToSpend, fee) = try utxoSelector.select(from: utxos, targetValue: amount)
//        let totalAmount: UInt64 = utxosToSpend.sum()
//        let change: UInt64 = totalAmount - amount - fee
//        let destinations: [(Address, UInt64)] = [(toAddress, amount), (address, change)]
//        let unsignedTx = try transactionBuilder.build(destinations: destinations, utxos: utxosToSpend)
//        let signedTx = try transactionSigner.sign(unsignedTx, with: [privateKey])
//
//        let rawtx = signedTx.serialized().hex
//        transactionBroadcaster.post(rawtx, completion: completion)
    }
    
    public func signShort(tx: QRAPITransaction, completion: ((_ txid: String?) -> Void)? = nil) throws {
        let utxos = utxoProvider.cached
        let (utxosToSpend, fee) = try utxoSelector.select(from: utxos, targetValue: amount)
        let totalAmount: UInt64 = utxosToSpend.sum()
        let change: UInt64 = totalAmount - amount - fee
        let destinations: [(Address, UInt64)] = [(address, amount), (address, change)]
        let unsignedTx = try transactionBuilder.buildFromQR(tx: tx)
        
        let signedTx = try transactionSigner.sign(unsignedTx, with: [privateKey])

        let rawtx = signedTx.serialized().hex
        transactionBroadcaster.post(rawtx, completion: completion)
    }
}

internal extension Sequence where Element == UnspentTransaction {
    func sum() -> UInt64 {
        return reduce(UInt64()) { $0 + $1.output.value }
    }
}

public struct QRAPITransaction: Codable {
    let inputs: [QRAPITransactionInput]
    let outputs: [QRAPITransactionOutput]
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        inputs = try container.decode([QRAPITransactionInput].self, forKey: .inputs)
        outputs = try container.decode([QRAPITransactionOutput].self, forKey: .outputs)
        
    }
    
}

public struct QRAPITransactionInput: Codable {
    let prev_hash: String
    let output_index: UInt32
    let sequence: UInt64
    let locking_script: String
}

public struct QRAPITransactionOutput: Codable {
    let value: UInt64
    let locking_script: String
}


//{
//    "inputs": [
//    {
//        "prev_hash": "5ca3684895da9e3adb5bd9cc7394e77c053fd03192cac735d8206c6cf6af7399",
//        "output_index": 1,
//        "sequence": 4294967295,
//        "locking_script": "473044022043cce932a05bfadb6c814646626b3b450603b0e33c25ac89a5fc45e8a2f101a7022014bf8d81a7e9c19f68231da394a573e36b07e6751a7eaef4feefd4fd48de189401210271388f046ee56b4ae139cd14340bb5e3c575e7ac802f777cd49ba8d7ee03a4fb"
//        },
//    // ...
//    ],
//    "outputs": [
//    {
//        "locking_script": "76a9142c8f17abe088f6868dc21c5aa1e41887773a9c7888ac",
//        "value": 10000
//    },
//    // ...
//    ]
//}

