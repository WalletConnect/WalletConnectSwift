//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import WalletConnectSwift

class RequestTests: XCTestCase {

    let url = WCURL(topic: "topic", version: "1", bridgeURL: URL(string: "https://example.org/")!, key: "key")
    let method = "some_rpc_method_name"

    override func setUp() {
        super.setUp()
    }

    func test_noParameters() {
        let request = Request(url: url, method: method, id: "1")
        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.method, method)
        XCTAssertEqual(request.parameterCount, 0)
        XCTAssertThrowsError(try request.parameter(of: String.self, at: 0))
        XCTAssertThrowsError(try request.parameter(of: String.self, key: "param"))
        XCTAssertEqual(try request.json(), """
                                           {"id":"1","jsonrpc":"2.0","method":"\(method)"}
                                           """)
    }

    func test_idTypes() {
        let int = Request(url: url, method: method, id: 1)
        XCTAssertEqual(int.id as? Int, 1)
        XCTAssertEqual(int.internalID, .int(1))

        let double = Request(url: url, method: method, id: 1.0)
        XCTAssertEqual(double.id as! Double, 1.0, accuracy: 0.1)
        XCTAssertEqual(double.internalID, .double(1.0))

        let string = Request(url: url, method: method, id: "1")
        XCTAssertEqual(string.id as? String, "1")
        XCTAssertEqual(string.internalID, .string("1"))

        let null = Request(url: url, method: method, id: nil)
        XCTAssertNil(null.id as? String)
        XCTAssertEqual(null.internalID, .null)

        let `default` = Request(url: url, method: method)
        XCTAssertNotNil(`default`.id)
        XCTAssertNotNil(UUID(uuidString: `default`.id as! String))
    }

    func test_positionalParameters_empty() throws {
        let request = try Request(url: url, method: method, params: [String](), id: "1")
        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.method, method)
        XCTAssertEqual(request.parameterCount, 0)
        XCTAssertThrowsError(try request.parameter(of: String.self, at: 0))
        XCTAssertThrowsError(try request.parameter(of: String.self, key: "param"))
        XCTAssertEqual(try request.json(), """
                                           {"id":"1","jsonrpc":"2.0","method":"\(method)","params":[]}
                                           """)
    }

    struct A: Codable, Equatable {
        var a: String
    }

    func test_positionalParameters_one() throws {
        let one = try Request(url: url, method: method, params: ["1"])
        XCTAssertEqual(one.parameterCount, 1)
        XCTAssertEqual(try one.parameter(of: String.self, at: 0), "1")
    }

    func test_positionalParameters_object() throws {
        let object = try Request(url: url, method: method, params: [A(a: "1")])
        XCTAssertEqual(object.parameterCount, 1)
        XCTAssertEqual(try object.parameter(of: A.self, at: 0), A(a: "1"))

    }

    func test_positionalParameters_manyObjects() throws {
        let many = try Request(url: url, method: method, params: [A(a: "1"), A(a: "2")], id: "1")
        XCTAssertEqual(many.parameterCount, 2)
        XCTAssertEqual(try many.parameter(of: A.self, at: 1), A(a: "2"))
        XCTAssertEqual(try many.json(), """
                                        {"id":"1","jsonrpc":"2.0","method":"\(method)","params":[{"a":"1"},{"a":"2"}]}
                                        """)

    }

    struct B: Codable, Equatable {
        var a: String
        var b: String
    }

    func test_namedParameters_one() throws {
        let one = try Request(url: url, method: method, namedParams: A(a: "1"))
        XCTAssertEqual(one.parameterCount, 1)
        XCTAssertEqual(try one.parameter(of: String.self, key: "a"), "1")
        XCTAssertThrowsError(try one.parameter(of: A.self, at: 0))
    }

    func test_namedParameterse_two() throws {
        let two = try Request(url: url, method: method, namedParams: B(a: "1", b: "2"), id: "1")
        XCTAssertEqual(two.parameterCount, 2)
        XCTAssertEqual(try two.parameter(of: String.self, key: "a"), "1")
        XCTAssertEqual(try two.parameter(of: String.self, key: "b"), "2")
        XCTAssertNil(try two.parameter(of: String.self, key: "c"))
        XCTAssertEqual(try two.json(), """
                                       {"id":"1","jsonrpc":"2.0","method":"\(method)","params":{"a":"1","b":"2"}}
                                       """)
    }

}

