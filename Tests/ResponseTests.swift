//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import WalletConnectSwift

class ResponseTests: XCTestCase {
    let url = WCURL(topic: "topic", version: "1", bridgeURL: URL(string: "https://example.org/")!, key: "key")
    let method = "some_rpc_method_name"

    struct A: Codable, Equatable {
        var a: String
    }

    func test_withResult() throws {
        let string = try Response(url: url, value: "1", id: "1")
        XCTAssertEqual(string.internalID, .string("1"))
        XCTAssertEqual(string.url, url)
        XCTAssertEqual(try string.result(as: String.self), "1")
        XCTAssertNil(string.error)

        let object = try Response(url: url, value: A(a: "1"), id: "1")
        XCTAssertEqual(try object.result(as: A.self), A(a: "1"))

        let array = try Response(url: url, value: ["1"], id: "1")
        XCTAssertEqual(try array.result(as: [String].self), ["1"])

        let arrayOfObject = try Response(url: url, value: [A(a: "1")], id: "1")
        XCTAssertEqual(try arrayOfObject.result(as: [A].self), [A(a: "1")])
        XCTAssertEqual(try arrayOfObject.json(),    """
                                                    {"id":"1","jsonrpc":"2.0","result":[{"a":"1"}]}
                                                    """)

        let int = try Response(url: url, value: 1, id: 1)
        XCTAssertEqual(try int.result(as: Int.self), 1)
        XCTAssertEqual(int.internalID, .int(1))
        XCTAssertEqual(try int.json(),  """
                                        {"id":1,"jsonrpc":"2.0","result":1}
                                        """)

        let double = try Response(url: url, value: 1.0, id: 1.0)
        XCTAssertEqual(try double.result(as: Double.self), 1.0, accuracy: 0.1)
        XCTAssertEqual(double.internalID, .double(1.0))
    }

    func test_withCustomError() throws {
        let custom = try Response(url: url, errorCode: 1, message: "a", value: "b", id: "1")
        XCTAssertEqual(custom.url, url)
        XCTAssertEqual(custom.internalID, .string("1"))
        XCTAssertThrowsError(try custom.result(as: String.self))
        XCTAssertNotNil(custom.error)
        let error = custom.error!
        XCTAssertEqual(error.localizedDescription, "a")
        XCTAssertEqual(error.userInfo[WCResponseErrorDataKey] as? String, "\"b\"")
        XCTAssertEqual(try custom.json(),   """
                                            {"error":{"code":1,"data":"b","message":"a"},"id":"1","jsonrpc":"2.0"}
                                            """)
    }

    func test_withPredefinedError() throws {
        let request = Request(url: url, method: method, id: 1)
        let invalidJSON = try Response(request: request, error: .invalidJSON)
        XCTAssertNotNil(invalidJSON.error)
        XCTAssertEqual(invalidJSON.error?.code, ResponseError.invalidJSON.rawValue)
        XCTAssertEqual(invalidJSON.error?.localizedDescription, ResponseError.invalidJSON.message)
        XCTAssertEqual(invalidJSON.internalID, .int(1))

        let invalidRequest = try Response(url: url, error: .invalidRequest)
        XCTAssertEqual(invalidRequest.internalID, .null)
    }

    func test_staticInitializers() {
        let request = Request(url: url, method: method, id: 1)

        let rejection = Response.reject(request)
        XCTAssertEqual(rejection.internalID, request.internalID)
        XCTAssertEqual(rejection.error?.code, ResponseError.requestRejected.rawValue)

        let invalid = Response.invalid(request)
        XCTAssertEqual(invalid.internalID, request.internalID)
        XCTAssertEqual(invalid.error?.code, ResponseError.invalidRequest.rawValue)
    }

    func test_withJsonString() throws {
        let jsonString =
        """
        {"id":"1","jsonrpc":"2.0","result":[{"a":"1"}]}
        """
        let response = try Response(url: url, jsonString: jsonString)
        XCTAssertEqual(try response.json(), """
                                            {"id":"1","jsonrpc":"2.0","result":[{"a":"1"}]}
                                            """)
        XCTAssertEqual(response.url, url)
    }
}
