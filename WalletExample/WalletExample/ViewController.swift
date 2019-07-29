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
    
    private var wallet: Wallet?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.createWalletIfNeeded()
        self.updateLabels()
        destinationAddressTextField.text = "mjaZSjVVKbBMRUXtNLxzu88zHLxLfXpvL9"
    }
    
    func createWalletIfNeeded() {
        if wallet == nil {
            let userDefaults = UserDefaults.init()
            if let wif = userDefaults.getString(forKey: "wif"),
                let privateKey = try? PrivateKey(wif: wif) {
                wallet = Wallet(privateKey: privateKey)
                
            } else {
//                let privateKey = PrivateKey(network: .mainnetBTC)
                let words = ["gift", "pull", "daughter", "heavy", "outer", "damage", "timber", "tooth", "such", "fortune", "gift", "pitch"]
                
                
                let seed = Mnemonic.seed(mnemonic: words)
                let hdKey = HDPrivateKey(seed: seed, network: .mainnetBTC)
                let privateKey: PrivateKey = hdKey.privateKey()
//                let privateKey = PrivateKey(data: seed, network: .mainnetBTC)
                userDefaults.setString(privateKey.toWIF(), forKey: "wif")
                
                wallet = Wallet(privateKey: privateKey)
                
//                wallet?.save()
            }
        }
    }
    
    func updateLabels() {
        qrCodeImageView.image = wallet?.address.qrImage()
        addressLabel.text = wallet?.address.base58
        print(addressLabel.text)
        if let balance = wallet?.balance() {
            let b: Double = Double(balance)/100000000

            balanceLabel.text = "Balance: \(b) BTC";
//            balanceLabel.text = String(format: "Balance: %.9f BTC", b)
        }
    }
    
    func updateBalance() {
        wallet?.reloadBalance(completion: { [weak self] (balance) in
            DispatchQueue.main.async { self?.updateLabels() }
        })
//        wallet?.reloadTransactions(completion: { (txs) in
//            for tx in txs {
//                print("\(tx.value)")
//            }
//        })
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
            try wallet?.send(to: address, amount: 10000, completion: { [weak self] (response) in
                print(response ?? "")
                self?.updateBalance()
            })
        } catch {
            print(error)
        }
    }
}

