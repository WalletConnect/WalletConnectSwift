//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation
import CryptoSwift
import Security

struct HexString: Codable {
    var data: Data

    var string: String {
        return data.toHexString()
    }

    init(_ data: Data) {
        self.data = data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self.init(value)
    }

    init(_ string: String) {
        data = Data(hex: string)
    }
}

class AES_256_CBC_HMAC_SHA256_Codec: Codec {
    struct EncryptionPayload: Codable {
        var data: HexString
        var hmac: HexString
        var iv: HexString
    }

    enum CodecError: Error {
        case stringToDataFailed(String)
        case dataToStringFailed(Data)
        case authenticationFailed(String)
    }

    func encode(plainText: String, key: String) throws -> String {
        let keyData = HexString(key).data
        let plainTextData = try data(string: plainText)
        let (cipherText, iv) = try encrypt(key: keyData, data: plainTextData)
        let hmac = try authenticationCode(key: keyData, data: cipherText + iv)
        let payload = EncryptionPayload(data: HexString(cipherText), hmac: HexString(hmac), iv: HexString(iv))
        let payloadData = try data(from: payload)
        let result = try string(data: payloadData)
        return result
    }

    func decode(cipherText: String, key: String) throws -> String {
        let cipherTextData = try data(string: cipherText)
        let payload = try self.payload(from: cipherTextData)
        let keyData = HexString(key).data
        let hmac = try authenticationCode(key: keyData, data: payload.data.data + payload.iv.data)
        guard hmac == payload.hmac.data else {
            throw CodecError.authenticationFailed(cipherText)
        }
        let plainTextData = try decrypt(key: keyData, data: payload.data.data, iv: payload.iv.data)
        let plainText = try string(data: plainTextData)
        return plainText
    }

    private func encrypt(key: Data, data: Data) throws -> (cipherText: Data, iv: Data) {
        let iv = AES.randomIV(AES.blockSize)
        let cipher = try AES(key: key.bytes, blockMode: CBC(iv: iv))
        let cipherText = try cipher.encrypt(data.bytes)
        return (Data(cipherText), Data(iv))
    }

    private func decrypt(key: Data, data: Data, iv: Data) throws -> Data {
        let cipher = try AES(key: key.bytes, blockMode: CBC(iv: iv.bytes))
        let plainText = try cipher.decrypt(data.bytes)
        return Data(plainText)
    }

    private func authenticationCode(key: Data, data: Data) throws -> Data {
        let algo = HMAC(key: key.bytes, variant: .sha2(.sha256))
        let digest = try algo.authenticate(data.bytes)
        return Data(digest)
    }

    private func data(string: String) throws -> Data {
        if let data = string.data(using: .utf8) {
            return data
        } else {
            throw CodecError.stringToDataFailed(string)
        }
    }

    private func string(data: Data) throws -> String {
        if let string = String(data: data, encoding: .utf8) {
            return string
        } else {
            throw CodecError.dataToStringFailed(data)
        }
    }

    private func payload(from data: Data) throws -> EncryptionPayload {
        return try JSONDecoder().decode(EncryptionPayload.self, from: data)
    }

    private func data(from payload: EncryptionPayload) throws -> Data {
        return try JSONEncoder.encoder().encode(payload)
    }
}
