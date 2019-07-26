//
//  BitcoinComTransactionBroadcaster.swift
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

public final class BitcoinComTransactionBroadcaster: TransactionBroadcaster {
    private let endpoint: ApiEndPoint.BitcoinCom
    public init(network: Network) {
        self.endpoint = ApiEndPoint.BitcoinCom(network: network)
    }
    
    public func post(_ rawtx: String, completion: ((_ txid: String?) -> Void)?) {
        let url = endpoint.postRawtxURL(rawtx: rawtx)
        var request = URLRequest(url: url)

        let json: [String: Any] = ["tx": rawtx ]
        
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        
        request.httpMethod = "POST"
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, res, err in
            guard let data = data else {
                print("response is nil.")
                completion?(nil)
                return
            }
            guard let response = String(bytes: data, encoding: .utf8) else {
                print("broadcast response cannot be decoded.")
                completion?(nil)
                return
            }
        
            completion?(response)
        }
        task.resume()
    }
    
    
    public func txNew1(to toAddress: Address, from: Address, amount: UInt64, privateKey: PrivateKey, publicKey: PublicKey, completion: ((_ txid: String?) -> Void)?) {
        let url = endpoint.postTxNew1()
        var request = URLRequest(url: url)
        
        let json: [String: Any] = [
            "inputs": [
                ["addresses": [from.base58]]
            ],
            "outputs": [
                ["addresses": [toAddress.base58],
                 "value": amount ]
            ]
        ]
        //        let json: [String: Any] = ["tx": rawtx ]
        
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        
        request.httpMethod = "POST"
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, res, err in
            guard let data = data else {
                print("response is nil.")
                completion?(nil)
                return
            }
            
            print("----------")
            print("\(String(data: data, encoding: .utf8))")
            print("----------")
            
            guard let r2 = try? JSONDecoder().decode(BitcoinComResponseModel.self, from: data) else {
                print("data cannot be decoded to response")
                completion?(nil)
                return
            }
            
            if let signed = self.signHash(hashes: r2.tosign, privateKey: privateKey, publicKey: publicKey) {
                self.sendSignedTx(signatures: signed.signatures, publicKeys: signed.publicKeys, response: r2, completion: completion)
            } else {
                completion?(nil)
            }
        }
        task.resume()
    }
    
    public func signHash(hashes: [String], privateKey: PrivateKey, publicKey: PublicKey) -> (signatures: [String], publicKeys: [String])?{
        var signatures = [String]()
        var publicKeys = [String]()
        for tosign in hashes {
            let hxs = Data(hex: tosign);
            if  let tosignData = hxs,
                let signed = try? Crypto.sign2(tosignData, privateKey: privateKey) {
                print(privateKey)
                print(privateKey.data.hex)
                signatures.append(signed.hex)
                publicKeys.append(publicKey.data.hex)
            } else {
                return nil
            }
        }
        return (signatures: signatures, publicKeys: publicKeys)
    }
    
    private func sendSignedTx(signatures: [String], publicKeys: [String], response: BitcoinComResponseModel, completion: ((_ txid: String?) -> Void)?){
        if var response = response as? BitcoinComResponseModel {
            response.populate(signatures: signatures, pubkeys: publicKeys);
        
            var encoded: Data? = nil
            do {
                encoded = try JSONEncoder().encode(response)
            } catch {
                completion?(nil)
                print(error)
            }

            let url = endpoint.postTxSend1()
            
            var request = URLRequest(url: url)
            
//            let json: [String: Any] = [
//                "inputs": [
//                    ["addresses": [toAddress.base58]]
//                ],
//                "outputs": [
//                    ["addresses": [from.base58],
//                     "value": amount ]
//                ]
//            ]
//            //        let json: [String: Any] = ["tx": rawtx ]
//
//            let jsonData = try? JSONSerialization.data(withJSONObject: json)
//
            request.httpMethod = "POST"
            request.httpBody = encoded
            
        if let encodedData = encoded {
            print("\(String(data: encodedData, encoding: .utf8))")
        }
            
            let task = URLSession.shared.dataTask(with: request) { data, res, err in
                guard let data = data else {
                    print("response is nil.")
                    completion?(nil)
                    return
                }
                print("============")
                print("\(String(data: data, encoding: .utf8))")
                print("============")
                do {
                    let rr2 = try JSONDecoder().decode(BitcoinComResponseModel.self, from: data)
                } catch {
                    print("error \(error)");
                }
                guard let r2 = try? JSONDecoder().decode(BitcoinComResponseModel.self, from: data) else {
                    print("data cannot be decoded to response")
                    completion?(nil)
                    return
                }
                
                print(r2);
                completion?(r2.tx.hash)
//                guard let r2 = String(bytes: data, encoding: .utf8) else {
//                    print("broadcast response cannot be decoded.")
//                    return
//                }
//                print(r2)
            }
            task.resume();
//            if let encodedData = encoded {
//                print("\(String(data: encodedData, encoding: .utf8))")
//            }
//            if let encodedData = try? JSONEncoder().encode(response) {
//                print("\(String(data: encodedData, encoding: .utf8))")
//            }
        }
    }
}

private struct BitcoinComResponseModel: Codable {
    let tx: BitcoinComTxModel
    let tosign: [String]
    var signatures: [String]
    var pubkeys: [String]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tx = try container.decode(BitcoinComTxModel.self, forKey: .tx);
        tosign = try container.decode([String].self, forKey: .tosign)
        signatures = []
        pubkeys = []
    }
    mutating func populate(signatures: [String], pubkeys: [String]) {
        self.signatures = signatures
        self.pubkeys = pubkeys
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
    let confirmed: String? // Date
    let received: String // Date
    let ver: Int
    let lock_time: Int?
    let double_spend: Bool
    let vin_sz: Int
    let vout_sz: Int
    let confirmations: Int
    let confidence: Int?
    let inputs: [BitcointComTxInputModel]
    let outputs: [BitcointComTxOutputModel]
    
    enum CodingKeys: String, CodingKey {
        case block_hash, block_height, hash, addresses, total, fees, size, preference, relayed_by, confirmed, received,
        ver, lock_time, double_spend, vin_sz, vout_sz, confirmations, confidence, inputs, outputs
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        block_hash = try? container.decode(String.self, forKey: .block_hash)
        block_height = try container.decode(Int.self, forKey: .block_height)
        hash = try container.decode(String.self, forKey: .hash)
        addresses = try container.decode([String].self, forKey: .addresses)
        total = try container.decode(Int.self, forKey: .total)
        fees = try container.decode(Int.self, forKey: .fees)
        size = try container.decode(Int.self, forKey: .size)
        preference = try container.decode(String.self, forKey: .preference)
        relayed_by = try container.decode(String.self, forKey: .relayed_by)
        confirmed = try? container.decode(String.self, forKey: .confirmed)
        received = try container.decode(String.self, forKey: .received)
        ver = try container.decode(Int.self, forKey: .ver)
        lock_time = try? container.decode(Int.self, forKey: .lock_time)
        double_spend = try container.decode(Bool.self, forKey: .double_spend)
        vin_sz = try container.decode(Int.self, forKey: .vin_sz)
        vout_sz = try container.decode(Int.self, forKey: .vout_sz)
        confirmations = try container.decode(Int.self, forKey: .confirmations)
        confidence = try? container.decode(Int.self, forKey: .confidence)
        
        inputs = try container.decode([BitcointComTxInputModel].self, forKey: .inputs);
        outputs = try container.decode([BitcointComTxOutputModel].self, forKey: .outputs);
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if block_hash != nil {
            try container.encode(block_hash, forKey: .block_hash)
        }
        if confidence != nil {
            try container.encode(confidence, forKey: .confidence)
        }
        if confirmed != nil {
            try container.encode(confirmed, forKey: .confirmed)
        }
        if lock_time != nil {
            try container.encode(lock_time, forKey: .lock_time)
        }
    
        try container.encode(block_height, forKey: .block_height)
        try container.encode(hash, forKey: .hash)
        try container.encode(addresses, forKey: .addresses)
        try container.encode(total, forKey: .total)
        try container.encode(fees, forKey: .fees)
        try container.encode(size, forKey: .size)
        try container.encode(preference, forKey: .preference)
        try container.encode(relayed_by, forKey: .relayed_by)
        try container.encode(received, forKey: .received)
        try container.encode(ver, forKey: .ver)
        try container.encode(double_spend, forKey: .double_spend)
        try container.encode(vin_sz, forKey: .vin_sz)
        try container.encode(confirmations, forKey: .confirmations)
        try container.encode(inputs, forKey: .inputs)
        try container.encode(outputs, forKey: .outputs)
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
    
    enum CodingKeys: String, CodingKey {
        case prev_hash, output_index, script, output_value, sequence, addresses, script_type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        prev_hash = try container.decode(String.self, forKey: .prev_hash)
        output_index = try container.decode(Int.self, forKey: .output_index)
        script = try? container.decode(String.self, forKey: .script)
        output_value = try container.decode(Int.self, forKey: .output_value)
        sequence = try container.decode(Int.self, forKey: .sequence)
        addresses = try container.decode([String].self, forKey: .addresses)
        script_type = try container.decode(String.self, forKey: .script_type)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(prev_hash, forKey: .prev_hash)
        try container.encode(output_index, forKey: .output_index)
        if script != nil {
            try container.encode(script, forKey: .script)
        }
        try container.encode(output_value, forKey: .output_value)
        try container.encode(sequence, forKey: .sequence)
        try container.encode(addresses, forKey: .addresses)
        try container.encode(script_type, forKey: .script_type)
    }
}

private struct BitcointComTxOutputModel: Codable {
    let value: Int
    let script: String
    let addresses: [String]
    let script_type: String
    
    enum CodingKeys: String, CodingKey {
        case value, script, addresses, script_type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        value = try container.decode(Int.self, forKey: .value)
        script = try container.decode(String.self, forKey: .script)
        addresses = try container.decode([String].self, forKey: .addresses)
        script_type = try container.decode(String.self, forKey: .script_type)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(script, forKey: .script)
        try container.encode(script_type, forKey: .script_type)
        try container.encode(addresses, forKey: .addresses)
    }
}
