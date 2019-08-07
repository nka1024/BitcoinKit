//
//  ViewController.swift
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

import UIKit
import BitcoinKit


class ViewController: UIViewController {
    @IBOutlet private weak var qrCodeImageView: UIImageView!
    @IBOutlet private weak var addressLabel: UILabel!
    @IBOutlet private weak var balanceLabel: UILabel!
    @IBOutlet private weak var destinationAddressTextField: UITextField!
    
    private var walletBTC: Wallet?
    private var walletBCH: Wallet?
    
    private let isBTC: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.createBTCWalletIfNeeded()
        self.createBCHWalletIfNeeded()
        self.updateLabels()
        destinationAddressTextField.text = "mjaZSjVVKbBMRUXtNLxzu88zHLxLfXpvL9"
    }
    
    func createBTCWalletIfNeeded() {
        if walletBTC == nil {
            let userDefaults = UserDefaults.init()
            if let mnemonic = userDefaults.getString(forKey: "mnemonicBtc") {
                let words = mnemonic.split(separator: " ").map({String($0)})
                let seed = Mnemonic.seed(mnemonic: words)
                let privateKey: PrivateKey = PrivateKey(data: seed, network: .mainnetBTC, isPublicKeyCompressed: false)
                walletBTC = Wallet.walletBTC(privateKey: privateKey)
            } else {
                let words = ["gift", "pull", "daughter", "heavy", "outer", "damage", "timber", "tooth", "such", "fortune", "gift", "pitch"]
                let seed = Mnemonic.seed(mnemonic: words)
                let privateKey: PrivateKey = PrivateKey(data: seed, network: .mainnetBTC, isPublicKeyCompressed: false)
                
                let mnemonicString = words.joined(separator: " ")
                userDefaults.set(mnemonicString, forKey: "mnemonicBtc")
                walletBTC = Wallet.walletBTC(privateKey: privateKey)
            }
        }
    }
    
    func createBCHWalletIfNeeded() {
        if walletBCH == nil {
            let userDefaults = UserDefaults.init()
            if let mnemonic = userDefaults.getString(forKey: "mnemonicBch") {
                let words = mnemonic.split(separator: " ").map({String($0)})
                let seed = Mnemonic.seed(mnemonic: words)
                let privateKey: PrivateKey = PrivateKey(data: seed, network: .mainnet, isPublicKeyCompressed: false)
                walletBCH = Wallet(privateKey: privateKey)
            } else {
                if let mnemonic = try? Mnemonic.generate() {
                    let seed = Mnemonic.seed(mnemonic: mnemonic)
                    print("bch seed: \(mnemonic)")
                    let privateKey: PrivateKey = PrivateKey(data: seed, network: .mainnet, isPublicKeyCompressed: false)
                    
                    let mnemonicString = mnemonic.joined(separator: " ")
                    userDefaults.setString(mnemonicString, forKey: "mnemonicBch")
                    walletBCH = Wallet(privateKey: privateKey)
                }
            }
        }
    }
    
    func updateLabels() {
        if isBTC {
            qrCodeImageView.image = walletBTC?.address.qrImage()
            addressLabel.text = walletBTC?.address.base58
            print(addressLabel.text ?? "")
            if let balance = walletBTC?.balance() {
                let b: Double = Double(balance)/100000000
                
                balanceLabel.text = "Balance: \(b) BTC";
        //            balanceLabel.text = String(format: "Balance: %.9f BTC", b)
            }
        } else {
            qrCodeImageView.image = walletBCH?.address.qrImage()
            addressLabel.text = walletBCH?.address.cashaddr
            print(walletBCH?.address.base58 ?? "")
            print(walletBCH?.address.cashaddr ?? "")
            print(addressLabel.text ?? "")
            if let balance = walletBCH?.balance() {
                let b: Double = Double(balance)/100000000
                
                balanceLabel.text = "Balance: \(b) BCH";
            }
        }
    }
    
    func updateBalance() {
        if (isBTC) {
            walletBTC?.reloadBalance(completion: { [weak self] (balance) in
                DispatchQueue.main.async { self?.updateLabels() }
            })
            walletBTC?.reloadTransactions(completion: { (txs) in
                for tx in txs {
                    let sign = tx.positive ? "+" : "-"
                    print("\(sign)\(tx.value)")
                }
            })
            walletBTC?.reloadFees(completion: {[weak self] fastest in
                print("fastest fee rate: \(self?.walletBTC?.fastestFeeBTC ?? 0)")
            })
        } else {
            walletBCH?.reloadBalance(completion: { [weak self] (balance) in
                DispatchQueue.main.async { self?.updateLabels() }
            })
            walletBCH?.reloadTransactions(completion: { (txs) in
                for tx in txs {
                    let sign = tx.positive ? "+" : "-"
                    print("\(sign)\(tx.value)")
                }
            })
            walletBCH?.reloadFees(completion: {[weak self] fastest in
                print("fastest fee rate: \(self?.walletBCH?.fastestFeeBTC ?? 0)")
            })
        }
        
    }
    
    @IBAction func didTapReloadBalanceButton(_ sender: UIButton) {
        updateBalance()
    }
    
    @IBAction func didTapSendButton(_ sender: UIButton) {
        guard let addressString = destinationAddressTextField.text else {
            return
        }
        
        do {
            let address: Address = try AddressFactory.create(addressString)
            try walletBTC?.send(to: address, amount: 10000, completion: { [weak self] (response) in
                print(response ?? "")
                self?.updateBalance()
            })
        } catch {
            print(error)
        }
    }
}

