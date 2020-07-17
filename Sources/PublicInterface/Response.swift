//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

public class Response {
    public var url: WCURL

    internal var internalID: JSONRPC_2_0.IDType {
        return payload.id
    }

    private var payload: JSONRPC_2_0.Response

    internal init(payload: JSONRPC_2_0.Response, url: WCURL) {
        self.payload = payload
        self.url = url
    }

    public convenience init<T: Encodable>(url: WCURL, value: T, id: RequestID) throws {
        let result = try JSONRPC_2_0.Response.Payload.value(JSONRPC_2_0.ValueType(value))
        let response = JSONRPC_2_0.Response(result: result, id: JSONRPC_2_0.IDType(id))
        self.init(payload: response, url: url)
    }

    public convenience init<T: Encodable>(url: WCURL, errorCode: Int, message: String, value: T?, id: RequestID?) throws {
        let code = try JSONRPC_2_0.Response.Payload.ErrorPayload.Code(errorCode)
        let data: JSONRPC_2_0.ValueType? = try value == nil ? nil : JSONRPC_2_0.ValueType(value!)
        let error = JSONRPC_2_0.Response.Payload.ErrorPayload(code: code, message: message, data: data)
        let result = JSONRPC_2_0.Response.Payload.error(error)
        let response = JSONRPC_2_0.Response(result: result, id: JSONRPC_2_0.IDType(id))
        self.init(payload: response, url: url)
    }

    public convenience init(url: WCURL, errorCode: Int, message: String, id: RequestID?) throws {
        try self.init(url: url, errorCode: errorCode, message: message, value: Optional<String>.none, id: id)
    }

    public convenience init(request: Request, error: ResponseError) throws {
        try self.init(url: request.url,
                      errorCode: error.rawValue,
                      message: error.message,
                      id: request.id)
    }

    public convenience init(url: WCURL, error: ResponseError) throws {
        try self.init(url: url,
                      errorCode: error.rawValue,
                      message: error.message,
                      id: nil)
    }

    public convenience init(url: WCURL, jsonString: String) throws {
        let payload = try JSONRPC_2_0.Response.create(from: JSONRPC_2_0.JSON(jsonString))
        self.init(payload: payload, url: url)
    }

    public func result<T: Decodable>(as type: T.Type) throws -> T {
        switch payload.result {
        case .error:
            throw ResponseError.errorResponse
        case .value(let value):
            return try value.decode(to: type)
        }
    }

    public var error: NSError? {
        switch payload.result {
        case .value: return nil
        case .error(let value):
            var userInfo: [String: Any] = [NSLocalizedDescriptionKey: value.message]
            if let data = value.data {
                userInfo[WCResponseErrorDataKey] = try? data.jsonString()
            }
            return NSError(domain: "org.walletconnect", code: value.code.code, userInfo: userInfo)
        }
    }

    internal func json() throws -> JSONRPC_2_0.JSON {
        return try payload.json()
    }

    public static func reject(_ request: Request) -> Response {
        return try! Response(request: request, error: .requestRejected)
    }

    public static func invalid(_ request: Request) -> Response {
        return try! Response(request: request, error: .invalidRequest)
    }
}

public let WCResponseErrorDataKey: String = "WCResponseErrorDataKey"

public enum ResponseError: Int, Error {
    case invalidJSON = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams = -32602
    case internalError = -32603

    case errorResponse = -32010
    case requestRejected = -32050

    public var message: String {
        switch self {
        case .invalidJSON: return "Parse error"
        case .invalidRequest: return "Invalid Request"
        case .methodNotFound: return "Method not found"
        case .invalidParams: return "Invalid params"
        case .internalError: return "Internal error"
        case .errorResponse: return "Error response"
        case .requestRejected: return "Request rejected"
        }
    }
}
