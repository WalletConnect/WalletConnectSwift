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

public enum JSONRPC_2_0 {

    struct JSON {

        var string: String

        init(_ text: String) {
            string = text
        }

    }

    enum IDType: Hashable, Codable {

        case string(String)
        case int(Int)
        case double(Double)
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .string(string)
            } else if let int = try? container.decode(Int.self) {
                self = .int(int)
            } else if let double = try? container.decode(Double.self) {
                self = .double(double)
            } else if container.decodeNil() {
                self = .null
            } else {
                let context = DecodingError.Context(codingPath: decoder.codingPath,
                                                    debugDescription: "Value is not a String, Number or Null")
                throw DecodingError.typeMismatch(IDType.self, context)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value):
                try container.encode(value)
            case .int(let value):
                try container.encode(value)
            case .double(let value):
                try container.encode(value)
            case .null:
                try container.encodeNil()
            }
        }

    }

    enum ValueType: Hashable, Codable {

        case object([String: ValueType])
        case array([ValueType])
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case null

        init(from decoder: Decoder) throws {
            if let keyedContainer = try? decoder.container(keyedBy: KeyType.self) {
                var result = [String: ValueType]()
                for key in keyedContainer.allKeys {
                    result[key.stringValue] = try keyedContainer.decode(ValueType.self, forKey: key)
                }
                self = .object(result)
            } else if var unkeyedContainer = try? decoder.unkeyedContainer() {
                var result = [ValueType]()
                while !unkeyedContainer.isAtEnd {
                    let value = try unkeyedContainer.decode(ValueType.self)
                    result.append(value)
                }
                self = .array(result)
            } else if let singleContainer = try? decoder.singleValueContainer() {
                if let string = try? singleContainer.decode(String.self) {
                    self = .string(string)
                } else if let int = try? singleContainer.decode(Int.self) {
                    self = .int(int)
                } else if let double = try? singleContainer.decode(Double.self) {
                    self = .double(double)
                } else if let bool = try? singleContainer.decode(Bool.self) {
                    self = .bool(bool)
                } else if singleContainer.decodeNil() {
                    self = .null
                } else {
                    let context = DecodingError.Context(codingPath: decoder.codingPath,
                                                        debugDescription: "Value is not a String, Number, Bool or Null")
                    throw DecodingError.typeMismatch(ValueType.self, context)
                }
            } else {
                let context = DecodingError.Context(codingPath: decoder.codingPath,
                                                    debugDescription: "Did not match any container")
                throw DecodingError.typeMismatch(ValueType.self, context)
            }
        }

        func encode(to encoder: Encoder) throws {
            switch self {
            case .object(let object):
                var container = encoder.container(keyedBy: KeyType.self)
                for (key, value) in object {
                    try container.encode(value, forKey: KeyType(stringValue: key)!)
                }
            case .array(let array):
                var container = encoder.unkeyedContainer()
                for value in array {
                    try container.encode(value)
                }
            case .string(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .int(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .double(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .bool(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .null:
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            }
        }

    }

    struct KeyType: CodingKey {

        var stringValue: String

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = try? Int(string: stringValue)
        }

        var intValue: Int?

        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = String(describing: intValue)
        }

    }

    /// https://www.jsonrpc.org/specification#request_object
    public struct Request: Hashable, Codable {

        let jsonrpc = "2.0"
        var method: String
        var params: Params?
        var id: IDType?

        enum CodableError: Error {
            case JSONstringToRequestFailed
            case requestToJSONstringFailed
        }

        enum Params: Hashable, Codable {

            case positional([ValueType])
            case named([String: ValueType])

            init(from decoder: Decoder) throws {
                if let keyedContainer = try? decoder.container(keyedBy: KeyType.self) {
                    var result = [String: ValueType]()
                    for key in keyedContainer.allKeys {
                        result[key.stringValue] = try keyedContainer.decode(ValueType.self, forKey: key)
                    }
                    self = .named(result)
                } else if var unkeyedContainer = try? decoder.unkeyedContainer() {
                    var result = [ValueType]()
                    while !unkeyedContainer.isAtEnd {
                        let value = try unkeyedContainer.decode(ValueType.self)
                        result.append(value)
                    }
                    self = .positional(result)
                } else {
                    let context = DecodingError.Context(codingPath: decoder.codingPath,
                                                        debugDescription: "Did not match any container")
                    throw DecodingError.typeMismatch(Params.self, context)
                }
            }

            func encode(to encoder: Encoder) throws {
                switch self {
                case .named(let object):
                    var container = encoder.container(keyedBy: KeyType.self)
                    for (key, value) in object {
                        try container.encode(value, forKey: KeyType(stringValue: key)!)
                    }
                case .positional(let array):
                    var container = encoder.unkeyedContainer()
                    for value in array {
                        try container.encode(value)
                    }
                }
            }

        }

    }

    /// https://www.jsonrpc.org/specification#request_object
    public struct Response: Hashable, Codable {

        let jsonrpc = "2.0"
        // TODO: test and change
        var result: Payload
        var id: IDType

        enum Payload: Hashable, Codable {

            case value(ValueType)
            case error(ErrorPayload)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let error = try? container.decode(ErrorPayload.self) {
                    self = .error(error)
                } else if let value = try? container.decode(ValueType.self) {
                    self = .value(value)
                } else {
                    let context = DecodingError.Context(codingPath: decoder.codingPath,
                                                        debugDescription: "Payload is neither error, nor JSON value")
                    throw DecodingError.typeMismatch(ValueType.self, context)
                }
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .value(let value):
                    try container.encode(value)
                case .error(let value):
                    try container.encode(value)
                }
            }

            struct ErrorPayload: Hashable, Codable {

                var code: Code
                var message: String
                var data: ValueType?

                // struct because some Int ranges are reserved and we want to require this in the Code itself
                struct Code: Hashable, Codable {

                    var code: Int

                    init(_ code: Int) {
                        self.code = code
                    }

                    init(from decoder: Decoder) throws {
                        let container = try decoder.singleValueContainer()
                        code = try container.decode(Int.self)
                    }

                    func encode(to encoder: Encoder) throws {
                        var container = encoder.singleValueContainer()
                        try container.encode(code)
                    }
                }

            }

        }

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
