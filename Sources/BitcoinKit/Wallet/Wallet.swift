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

final public class Wallet {
    public let privateKey: PrivateKey
    public let publicKey: PublicKey
    public var address: Address { return publicKey.toCashaddr() }

    public let network: Network
    private let walletDataStore: WalletDataStoreProtocol
    private let utxoProvider: UtxoProvider
    private let transactionProvider: TransactionProvider
    private let transactionBroadcaster: TransactionBroadcaster
    private let utxoSelector: UtxoSelector
    private let transactionBuilder: TransactionBuilder
    private let transactionSigner: TransactionSigner

    public init(privateKey: PrivateKey,
                walletDataStore: WalletDataStoreProtocol = UserDefaults.defaultWalletDataStore,
                utxoProvider: UtxoProvider = BitcoinComService.shared,
                transactionProvider: TransactionProvider = BitcoinComService.shared,
                transactionBroadcaster: TransactionBroadcaster = BitcoinComService.shared,
                utxoSelector: UtxoSelector = StandardUtxoSelector.default,
                transactionBuilder: TransactionBuilder = StandardTransactionBuilder.default,
                transactionSigner: TransactionSigner = StandardTransactionSigner.default) {
        self.privateKey = privateKey
        self.publicKey = privateKey.publicKey()
        self.network = privateKey.network

        self.walletDataStore = walletDataStore
        self.utxoProvider = utxoProvider
        self.transactionProvider = transactionProvider
        self.transactionBroadcaster = transactionBroadcaster
        self.utxoSelector = utxoSelector
        self.transactionBuilder = transactionBuilder
        self.transactionSigner = transactionSigner
    }

    public init?(wif: String,
                 walletDataStore: WalletDataStoreProtocol = UserDefaults.defaultWalletDataStore,
                 utxoProvider: UtxoProvider = BitcoinComService.shared,
                 transactionProvider: TransactionProvider = BitcoinComService.shared,
                 transactionBroadcaster: TransactionBroadcaster = BitcoinComService.shared,
                 utxoSelector: UtxoSelector = StandardUtxoSelector.default,
                 transactionBuilder: TransactionBuilder = StandardTransactionBuilder.default,
                 transactionSigner: TransactionSigner = StandardTransactionSigner.default) {
        guard let privkey = try? PrivateKey(wif: wif) else {
            return nil
        }
        self.privateKey = privkey
        self.publicKey = privkey.publicKey()
        self.network = privkey.network

        self.walletDataStore = walletDataStore
        self.utxoProvider = utxoProvider
        self.transactionProvider = transactionProvider
        self.transactionBroadcaster = transactionBroadcaster
        self.utxoSelector = utxoSelector
        self.transactionBuilder = transactionBuilder
        self.transactionSigner = transactionSigner
    }

    public init?(walletDataStore: WalletDataStoreProtocol = UserDefaults.defaultWalletDataStore,
                 utxoProvider: UtxoProvider = BitcoinComService.shared,
                 transactionProvider: TransactionProvider = BitcoinComService.shared,
                 transactionBroadcaster: TransactionBroadcaster = BitcoinComService.shared,
                 utxoSelector: UtxoSelector = StandardUtxoSelector.default,
                 transactionBuilder: TransactionBuilder = StandardTransactionBuilder.default,
                 transactionSigner: TransactionSigner = StandardTransactionSigner.default) {
        guard let wif = walletDataStore.getString(forKey: .wif) else {
            return nil
        }
        guard let privkey = try? PrivateKey(wif: wif) else {
            return nil
        }
        self.privateKey = privkey
        self.publicKey = privkey.publicKey()
        self.network = privkey.network

        self.walletDataStore = walletDataStore
        self.utxoProvider = utxoProvider
        self.transactionProvider = transactionProvider
        self.transactionBroadcaster = transactionBroadcaster
        self.utxoSelector = utxoSelector
        self.transactionBuilder = transactionBuilder
        self.transactionSigner = transactionSigner
    }

    public func save() {
        walletDataStore.setString(privateKey.toWIF(), forKey: .wif)
    }

    public func reloadBalance(completion: (([UnspentTransaction]) -> Void)? = nil) {
        utxoProvider.reload(addresses: [address], completion: completion)
    }

    public func balance() -> UInt64 {
        return utxoProvider.list().sum()
    }

    public func utxos() -> [UnspentTransaction] {
        return utxoProvider.list()
    }

    public func transactions() -> [Transaction] {
        return transactionProvider.list()
    }

    public func reloadTransactions(completion: (([Transaction]) -> Void)? = nil) {
        transactionProvider.reload(addresses: [address], completion: completion)
    }

    public func send(to toAddress: Address, amount: UInt64, completion: ((_ txid: String?) -> Void)? = nil) throws {
        let utxos = utxoProvider.list()
        let (utxosToSpend, fee) = try utxoSelector.select(from: utxos, targetValue: amount)
        let totalAmount: UInt64 = utxosToSpend.sum()
        let change: UInt64 = totalAmount - amount - fee
        let destinations: [(Address, UInt64)] = [(toAddress, amount), (address, change)]
        let unsignedTx = try transactionBuilder.build(destinations: destinations, utxos: utxosToSpend)
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
