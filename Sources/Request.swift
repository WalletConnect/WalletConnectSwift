//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

public class Request {

    public var url: WCURL

    public var method: Method {
        return payload.method
    }
    public var id: RequestID? {
        return internalID?.requestID
    }

    internal var internalID: JSONRPC_2_0.IDType? {
        return payload.id
    }

    private var payload: JSONRPC_2_0.Request

    internal init(payload: JSONRPC_2_0.Request, url: WCURL) {
        self.payload = payload
        self.url = url
    }

    public convenience init(url: WCURL, method: Method, params: [Encodable], id: RequestID? = UUID().uuidString) throws {
        let values = try params.map { try JSONRPC_2_0.ValueType($0) }
        let parameters = JSONRPC_2_0.Request.Params.positional(values)
        let payload = JSONRPC_2_0.Request(method: method, params: parameters, id: JSONRPC_2_0.IDType(id))
        self.init(payload: payload, url: url)
    }

    public convenience init(url: WCURL, method: Method, params: Encodable, id: RequestID? = UUID().uuidString) throws {
        let data = try JSONEncoder().encode(AnyEncodable(value: params))
        let values = try JSONDecoder().decode([String: JSONRPC_2_0.ValueType].self, from: data)
        let parameters = JSONRPC_2_0.Request.Params.named(values)
        let payload = JSONRPC_2_0.Request(method: method, params: parameters, id: JSONRPC_2_0.IDType(id))
        self.init(payload: payload, url: url)
    }


    public var parameterCount: Int {
        guard let params = payload.params else { return 0 }
        switch params {
        case .named(let values): return values.count
        case .positional(let values): return values.count
        }
    }

    public func parameter<T: Decodable>(of type: T.Type, at position: Int) throws -> T {
        guard let params = payload.params else {
            throw RequestError.parametersDoNotExist
        }
        switch params {
        case .named:
            throw RequestError.positionalParametersDoNotExist
        case .positional(let values):
            if position >= values.count {
                throw RequestError.parameterPositionOutOfBounds
            }
            let param = values[0]
            let data = try JSONEncoder().encode(param)
            let result = try JSONDecoder().decode(type, from: data)
            return result
        }
    }

    public func parameter<T: Decodable>(of type: T.Type, key: String) throws -> T? {
        guard let params = payload.params else {
            throw RequestError.parametersDoNotExist
        }

        switch params {
        case .positional:
            throw RequestError.namedParametersDoNotExist
        case .named(let values):
            guard let value = values[key] else {
                return nil
            }
            let data = try JSONEncoder().encode(value)
            let result = try JSONDecoder().decode(type, from: data)
            return result
        }
    }

    internal func json() throws -> JSONRPC_2_0.JSON {
        return try payload.json()
    }
}


public enum RequestError: Error {
    case positionalParametersDoNotExist
    case parametersDoNotExist
    case parameterPositionOutOfBounds
    case namedParametersDoNotExist
}

/// RPC method names are Strings
public typealias Method = String

/// Protocol marker for request identifier type. It is any value of types String, Int, Double, or nil
public protocol RequestID {}

extension String: RequestID {}
extension Int: RequestID {}
extension Double: RequestID {}

// problem: using Encodable as-is in JSONEncoder().encode(encodable) generates error
// because the encodable has its type erased. Therefore, we wrap it in a concrete struct!
//
// thanks to http://www.yourfriendlyioscoder.com/blog/2019/04/27/any-encodable/
internal struct AnyEncodable: Encodable {

    let value: Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        // container.encode(value) doesn't work because of the error (see comment above)
        try value.encode(to: &container)
    }

}

internal extension Encodable {

    func encode(to container: inout SingleValueEncodingContainer) throws {
        // here, `self` knows what concrete type it is, so it encodes happily
        try container.encode(self)
    }

}

internal extension JSONRPC_2_0.ValueType {

    init(_ value: Encodable) throws {
        let data = try JSONEncoder().encode(AnyEncodable(value: value))
        self = try JSONDecoder().decode(JSONRPC_2_0.ValueType.self, from: data)
    }

}

internal extension JSONRPC_2_0.IDType {

    init(_ value: RequestID?) {
        switch value {
        case .none: self = .null
        case .some(let wrapped):
            if wrapped is String {
                self = .string((wrapped as! String))
            } else if wrapped is Int {
                self = .int(wrapped as! Int)
            } else if wrapped is Double {
                self = .double(wrapped as! Double)
            } else {
                preconditionFailure("Unknown Request ID IDType")
            }
        }
    }

    var requestID: RequestID? {
        switch self {
        case .string(let value): return value
        case .int(let value): return value
        case .double(let value): return value
        case .null: return nil
        }
    }

}
