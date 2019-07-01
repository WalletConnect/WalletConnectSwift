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

class JSONRPCSerializer: RequestSerializer, ResponseSerializer {

    private let codec: Codec = AES_256_CBC_HMAC_SHA256_Codec()
    private let pubSubAdapter: PubSubAdapter = PubSubAdapter()
    private let jsonrpc = JSONRPCAdapter()

    func serialize(_ request: Request) throws -> String {
        let json = try jsonrpc.json(from: request)
        let cipherText = try codec.encode(plainText: json.string, key: request.id.origin.key)
        let message = PubSubAdapter.Message(topic: request.id.origin.topic, type: .pub, payload: cipherText)
        let result = try pubSubAdapter.string(from: message)
        return result
    }

    func deserialize(_ text: String, url: WCURL) throws -> Request {
        let message = try pubSubAdapter.message(from: text)
        let plainText = try codec.decode(cipherText: message.payload, key: url.key)
        let result = try jsonrpc.request(from: JSONRPC.JSON(plainText))
        result.setOrigin(url)
        return result
    }

    func serialize(_ response: Response) throws -> String {
        let json = try jsonrpc.json(from: response)
        let cipherText = try codec.encode(plainText: json.string, key: response.origin.key)
        let message = PubSubAdapter.Message(topic: response.origin.topic, type: .pub, payload: cipherText)
        let result = try pubSubAdapter.string(from: message)
        return result
    }

    func deserialize(_ text: String, url: WCURL) throws -> Response {
        let message = try pubSubAdapter.message(from: text)
        let plainText = try codec.decode(cipherText: message.payload, key: url.key)
        let result = try jsonrpc.response(from: JSONRPC.JSON(plainText))
        result.setOrigin(url)
        return result
    }

}

protocol Codec {

    func encode(plainText: String, key: String) throws -> String
    func decode(cipherText: String, key: String) throws -> String

}

enum JSONRPC {

    enum ValueType: Hashable, Codable {

        case object([String: ValueType])
        case array([ValueType])
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case null

        init(from decoder: Decoder) throws {
            if let singleContainer = try? decoder.singleValueContainer() {
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
            } else if let keyedContainer = try? decoder.container(keyedBy: KeyType.self) {
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
                throw DecodingError.typeMismatch(ValueType.self, context)
            }
        }

        func encode(to encoder: Encoder) throws {
            switch self {
            case .string(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .int(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .double(let value):
                var container = encoder.singleValueContainer()
                try container.encode(value)
            case .null:
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            }
        }

    }

    struct Version: Hashable, Codable {

        var string: String

        static let V2 = Version("2.0")

        init(_ string: String) {
            self.string = string
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            string = try container.decode(String.self)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(string)
        }

    }

    // TODO: decoding must verify JSONRPC 2.0 rules
    struct Request: Codable {

        var jsonrpc: Version
        var method: MethodName
        var params: Params?
        var id: IDType?

        struct MethodName: Hashable, Codable {

            var name: String

            init(_ name: String) {
                self.name = name
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                name = try container.decode(String.self)
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encode(name)
            }

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
                    throw DecodingError.typeMismatch(ValueType.self, context)
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

    // TODO: decoding must verify JSONRPC 2.0 rules
    struct Response: Codable {

        var jsonrpc: Version
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

    struct JSON {

        var string: String

        init(_ text: String) {
            string = text
        }

    }

}

class JSONRPCAdapter {

    func json(from: Request) throws -> JSONRPC.JSON {
        preconditionFailure()
    }

    func request(from: JSONRPC.JSON) throws -> Request {
        preconditionFailure()
    }

    func json(from: Response) throws -> JSONRPC.JSON {
        preconditionFailure()
    }

    func response(from: JSONRPC.JSON) throws -> Response {
        preconditionFailure()
    }

}
