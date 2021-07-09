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
    public var jsonString: String {
        if let str = try? json().string {
            return str
        }
        return ""
    }

    internal var internalID: JSONRPC_2_0.IDType? {
        return payload.id
    }

    private var payload: JSONRPC_2_0.Request

    internal init(payload: JSONRPC_2_0.Request, url: WCURL) {
        self.payload = payload
        self.url = url
    }
    
    /// Generates new ID for a request that is compatible with JS clients.
    /// - Returns: new ID
    public static func payloadId() -> RequestID {
        // Port of the payloadId() from the JS library to make sure that
        // generated IDs fit into JS's number size (max integer size is
        // 2^53 - 1).
        //
        // NOTE: new Date().getTime() is time in milliseconds in JS, however,
        // in iOS it is time in seconds. So instead of 1000, we multiply by 1 million
        //
        // NOTE: the id may still be greater than JS max number, but
        // this would happen if the date is in year 2255
        //
        // JS code:
        //    const datePart: number = new Date().getTime() * Math.pow(10, 3)
        //    const extraPart: number = Math.floor(Math.random() * Math.pow(10, 3))
        //    const id: number = datePart + extraPart
        let datePart = Int(Date().timeIntervalSince1970 * 1000_000)
        let extraPart = Int.random(in: 0..<1000)
        let id = datePart + extraPart
        return id
    }

    public convenience init(url: WCURL, method: Method, id: RequestID? = payloadId()) {
        let payload = JSONRPC_2_0.Request(method: method, params: nil, id: JSONRPC_2_0.IDType(id))
        self.init(payload: payload, url: url)
    }

    public convenience init<T: Encodable>(url: WCURL, method: Method, params: [T], id: RequestID? = payloadId()) throws {
        let data = try JSONEncoder.encoder().encode(params)
        let values = try JSONDecoder().decode([JSONRPC_2_0.ValueType].self, from: data)
        let parameters = JSONRPC_2_0.Request.Params.positional(values)
        let payload = JSONRPC_2_0.Request(method: method, params: parameters, id: JSONRPC_2_0.IDType(id))
        self.init(payload: payload, url: url)
    }

    public convenience init<T: Encodable>(url: WCURL, method: Method, namedParams params: T, id: RequestID? = payloadId()) throws {
        let data = try JSONEncoder.encoder().encode(params)
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
            return try values[position].decode(to: type)
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
            return try value.decode(to: type)
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


internal extension JSONRPC_2_0.ValueType {
    init<T: Encodable>(_ value: T) throws {
        // Encodable types can be primitives (i.e. String), which encode to invalid JSON (root must be Array or Dict)
        let wrapped = try JSONEncoder.encoder().encode([value])
        let unwrapped = try JSONDecoder().decode([JSONRPC_2_0.ValueType].self, from: wrapped)
        self = unwrapped[0]
    }

    func decode<T: Decodable>(to type: T.Type) throws -> T {
        let data = try JSONEncoder.encoder().encode([self]) // wrap in array because values can be primitive types which is invalid json
        let result = try JSONDecoder().decode([T].self, from: data)
        return result[0]
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
