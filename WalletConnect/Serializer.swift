//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation


protocol ResponseSerializer {

    func serialize(_ response: Response) throws -> String
    func deserialize(_ text: String, url: WCURL) throws -> Response

}

protocol RequestSerializer {

    func serialize(_ request: Request) throws -> String
    func deserialize(_ text: String, url: WCURL) throws -> Request

}

protocol Codec {

    func encode(plainText: String, key: String) throws -> String
    func decode(cipherText: String, key: String) throws -> String

}

class JSONRPCSerializer: RequestSerializer, ResponseSerializer {

    private let codec: Codec = AES_256_CBC_HMAC_SHA256_Codec()
    private let pubSubAdapter: PubSubAdapter = PubSubAdapter()
    private let jsonrpc = JSONRPCAdapter()

    func serialize(_ request: Request) throws -> String {
        let json = try jsonrpc.json(from: request)
        let cipherText = try codec.encode(plainText: json.string, key: request.origin.key)
        let message = PubSubAdapter.Message(topic: request.origin.topic, type: .pub, payload: cipherText)
        let result = try pubSubAdapter.string(from: message)
        return result
    }

    /// Deserialize incoming WalletConnet text message.
    ///
    /// - Parameters:
    ///   - text: encoded text messafe
    ///   - url: WalletConnect session URL data (required for text decoding).
    /// - Returns: request object
    /// - Throws: deserialization errors
    func deserialize(_ text: String, url: WCURL) throws -> Request {
        let message = try pubSubAdapter.message(from: text)
        let JSONRPCPayloadText = try codec.decode(cipherText: message.payload, key: url.key)
        let result = try jsonrpc.request(from: JSONRPC_2_0.JSON(JSONRPCPayloadText), origin: url)
        return result
    }

    func serialize(_ response: Response) throws -> String {
        let json = try jsonrpc.json(from: response)
        let cipherText = try codec.encode(plainText: json.string, key: response.destination.key)
        let message = PubSubAdapter.Message(topic: response.destination.topic, type: .pub, payload: cipherText)
        let result = try pubSubAdapter.string(from: message)
        return result
    }

    func deserialize(_ text: String, url: WCURL) throws -> Response {
        let message = try pubSubAdapter.message(from: text)
        let plainText = try codec.decode(cipherText: message.payload, key: url.key)
        let result = try jsonrpc.response(from: JSONRPC_2_0.JSON(plainText))
//        result.setOrigin(url)
        return result
    }

}

class JSONRPCAdapter {

    enum CodableError: Error {
        case JSONstringToRequestFailed
        case requestToJSONstringFailed
    }

    func json(from: Request) throws -> JSONRPC_2_0.JSON {
        preconditionFailure()
    }

    func request(from json: JSONRPC_2_0.JSON, origin: WCURL) throws -> Request {
        guard let data = json.string.data(using: .utf8) else {
            throw DataConversionError.stringToDataFailed
        }
        let JSONRPC_request = try JSONDecoder().decode(JSONRPC_2_0.Request.self, from: data)
        return Request(payload: JSONRPC_request, origin: origin)
    }

    func json(from: Response) throws -> JSONRPC_2_0.JSON {
        preconditionFailure()
    }

    func response(from: JSONRPC_2_0.JSON) throws -> Response {
        preconditionFailure()
    }

}
