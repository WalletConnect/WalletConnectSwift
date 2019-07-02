//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import MultisigWalletImplementations

// swiftlint:disable literal_expression_end_indentation
class SerializerTests: XCTestCase {

    func test_JSONRPC_ValueType_Serialization_Decerialization() throws {
        let data = JSONRPC_StubRequest.json1_Text.data(using: .utf8)!
        let res = try JSONDecoder().decode(JSONRPC_2_0.ValueType.self, from: data)
        XCTAssertEqual(res, JSONRPC_StubRequest.json1_ValueType)
        let data2 = try JSONEncoder().encode(JSONRPC_StubRequest.json1_ValueType)
        let res2 = try JSONDecoder().decode(JSONRPC_2_0.ValueType.self, from: data2)
        XCTAssertEqual(res2, JSONRPC_StubRequest.json1_ValueType)
    }

    func test_JSONRPC_Request_Serialization_Decerialization() throws {
        let data = JSONRPC_StubRequest.json1_Text.data(using: .utf8)!
        let res = try JSONDecoder().decode(JSONRPC_2_0.Request.self, from: data)
        XCTAssertEqual(res, JSONRPC_StubRequest.json1_Request)
        let data2 = try JSONEncoder().encode(JSONRPC_StubRequest.json1_Request)
        let res2 = try JSONDecoder().decode(JSONRPC_2_0.Request.self, from: data2)
        XCTAssertEqual(res2, JSONRPC_StubRequest.json1_Request)
    }

    // TODO: add more test for other types

}

fileprivate struct JSONRPC_StubRequest {

    static let json1_Text = """
{
    "id": 100,
    "jsonrpc": "2.0",
    "method": "wc_sessionRequest",
    "params": {
        "peerId": "peerId",
        "peerMeta": {
            "description": "Good trades take time.",
            "url": "https://slow.trade",
            "icons": ["https://test.com/icon1.png", "https://test.com/icon2.png"],
            "name": "Slow Trade"
        }
    }
}
"""
    static let json1_ValueType = JSONRPC_2_0.ValueType.object([
        "id": .int(100),
        "jsonrpc": .string("2.0"),
        "method": .string("wc_sessionRequest"),
        "params": .object([
            "peerId": .string("peerId"),
            "peerMeta": .object([
                "description": .string("Good trades take time."),
                "url": .string("https://slow.trade"),
                "icons": .array([.string("https://test.com/icon1.png"), .string("https://test.com/icon2.png")]),
                "name": .string("Slow Trade")
                ])
            ])
        ])

    static let json1_Request =
        JSONRPC_2_0.Request(method: "wc_sessionRequest",
                            params: JSONRPC_2_0.Request.Params.named([
                                "peerId": .string("peerId"),
                                "peerMeta": .object([
                                    "description": .string("Good trades take time."),
                                    "url": .string("https://slow.trade"),
                                    "icons": .array([.string("https://test.com/icon1.png"),
                                                     .string("https://test.com/icon2.png")]),
                                    "name": .string("Slow Trade")
                                    ])
                                ]),
                            id: JSONRPC_2_0.IDType.int(100))

}
