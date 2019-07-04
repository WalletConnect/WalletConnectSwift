//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation


/// We do not expect incomming responses as requests that we send are notifications.
protocol ResponseSerializer {

    /// Serialize WalletConnect Response into text message.
    ///
    /// - Parameter response: Response object
    /// - Returns: text message
    /// - Throws: serialization errors
    func serialize(_ response: Response) throws -> String

}

protocol RequestSerializer {

    /// Serialize WalletConnect Request into text message.
    ///
    /// - Parameter request: Request object
    /// - Returns: text message
    /// - Throws: serialization errors
    func serialize(_ request: Request) throws -> String

    /// Deserialize incoming WalletConnet text message.
    ///
    /// - Parameters:
    ///   - text: encoded text message
    ///   - url: WalletConnect session URL data (required for text decoding).
    /// - Returns: request object
    /// - Throws: deserialization errors
    func deserialize(_ text: String, url: WCURL) throws -> Request

}

protocol Codec {

    func encode(plainText: String, key: String) throws -> String
    func decode(cipherText: String, key: String) throws -> String

}

class JSONRPCSerializer: RequestSerializer, ResponseSerializer {

    private let codec: Codec = AES_256_CBC_HMAC_SHA256_Codec()
    private let jsonrpc = JSONRPCAdapter()

    // MARK: - RequestSerializer

    func serialize(_ request: Request) throws -> String {
        let jsonText = try jsonrpc.json(from: request)
        let cipherText = try codec.encode(plainText: jsonText, key: request.url.key)
        let message = PubSubMessage(topic: request.url.topic, type: .pub, payload: cipherText)
        return try message.json()
    }

    func deserialize(_ text: String, url: WCURL) throws -> Request {
        let message = try PubSubMessage.message(from: text)
        let payloadText = try codec.decode(cipherText: message.payload, key: url.key)
        let result = try jsonrpc.request(from: payloadText, url: url)
        return result
    }

    // MARK: - ResponseSerializer

    func serialize(_ response: Response) throws -> String {
        let jsonText = try jsonrpc.json(from: response)
        let cipherText = try codec.encode(plainText: jsonText, key: response.url.key)
        let message = PubSubMessage(topic: response.url.topic, type: .pub, payload: cipherText)
        return try message.json()
    }

}

fileprivate class JSONRPCAdapter {

    func json(from request: Request) throws -> String {
        return try request.payload.json().string
    }

    func request(from json: String, url: WCURL) throws -> Request {
        let JSONRPCRequest = try JSONRPC_2_0.Request.create(from: JSONRPC_2_0.JSON(json))
        return Request(payload: JSONRPCRequest, url: url)
    }

    func json(from response: Response) throws -> String {
        return try response.payload.json().string
    }

}
