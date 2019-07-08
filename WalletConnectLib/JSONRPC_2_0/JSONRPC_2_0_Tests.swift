//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import MultisigWalletImplementations

// swiftlint:disable literal_expression_end_indentation line_length
class JSONRPC_2_0_Tests: XCTestCase {

    let decoder = JSONDecoder()
    let encoder = JSONEncoder()

    func test_JSONRPC_ValueType_Serialization_Decerialization() throws {
        let data = JSONRPC_StubRequest.json1_Text.data(using: .utf8)!
        let res = try decoder.decode(JSONRPC_2_0.ValueType.self, from: data)
        XCTAssertEqual(res, JSONRPC_StubRequest.json1_ValueType)
        let data2 = try encoder.encode(JSONRPC_StubRequest.json1_ValueType)
        let res2 = try decoder.decode(JSONRPC_2_0.ValueType.self, from: data2)
        XCTAssertEqual(res2, JSONRPC_StubRequest.json1_ValueType)
    }

    func test_JSONRPC_Params_Serialization_Decerializatio() throws {
        let walletInfo = Session.WalletInfo(approved: false,
                                            accounts: [],
                                            chainId: 1,
                                            peerId: "1",
                                            peerMeta: Session.ClientMeta(name: "test",
                                                                         description: "test",
                                                                         icons: [],
                                                                         url: URL(string: "test")!))
        let walletInfoData = try encoder.encode(walletInfo)
        let paramsObject = try decoder.decode(JSONRPC_2_0.Request.Params.self, from: walletInfoData)
        let paramsData = try encoder.encode(paramsObject)
        let restoredWalletInfo = try! decoder.decode(Session.WalletInfo.self, from: paramsData)
        XCTAssertEqual(walletInfo.approved, restoredWalletInfo.approved)
        XCTAssertEqual(walletInfo.accounts, restoredWalletInfo.accounts)
        XCTAssertEqual(walletInfo.chainId, restoredWalletInfo.chainId)
    }

    func test_JSONRPC_Request_Serialization_Decerialization() throws {
        let req = try JSONRPC_2_0.Request.create(from: JSONRPC_2_0.JSON(JSONRPC_StubRequest.json1_Text))
        XCTAssertEqual(req, JSONRPC_StubRequest.json1_Request)
        let json = try JSONRPC_StubRequest.json1_Request.json()
        let req2 = try JSONRPC_2_0.Request.create(from: json)
        XCTAssertEqual(req, req2)
    }

    func test_JSONRPC_Response_Serialization_Decerialization() throws {
        // value payload
        let resp = try JSONRPC_2_0.Response.create(from: JSONRPC_2_0.JSON(JSONRPC_StubResposne.json1_Text))
        XCTAssertEqual(resp, JSONRPC_StubResposne.json1_Response)
        let json = try JSONRPC_StubResposne.json1_Response.json()
        let resp2 = try JSONRPC_2_0.Response.create(from: json)
        XCTAssertEqual(resp, resp2)

        // error payload
        let errResp = try JSONRPC_2_0.Response.create(from: JSONRPC_2_0.JSON(JSONRPC_StubResposne.json2_Text))
        XCTAssertEqual(errResp, JSONRPC_StubResposne.json2_Response)
        let json2 = try JSONRPC_StubResposne.json2_Response.json()
        XCTAssertTrue(json2.string.contains("error"))
        let errResp2 = try JSONRPC_2_0.Response.create(from: json2)
        XCTAssertEqual(errResp, errResp2)
    }

}

fileprivate enum JSONRPC_StubRequest {

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

fileprivate enum JSONRPC_StubResposne {

    static let json1_Text = """
{
    "id": 100,
    "jsonrpc": "2.0",
    "result": {
        "approved": true,
        "chainId": 1,
        "accounts": ["0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95", "0x46F228b5eFD19Be20952152c549ee478Bf1bf36b"]
    }
}
"""

    static let json1_Response =
        JSONRPC_2_0.Response(result: .value(.object(["approved": .bool(true),
                                                     "chainId": .int(1),
                                                     "accounts": .array([.string("0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95"),
                                                                         .string("0x46F228b5eFD19Be20952152c549ee478Bf1bf36b")])])),
                             id: .int(100))

    static let json2_Text = """
{
    "id": null,
    "jsonrpc": "2.0",
    "error": {
        "code": -30000,
        "message": "failure",
        "data": [1, 2, 3]
    }
}
"""

    static let json2_Response =
        JSONRPC_2_0.Response(result: .error(JSONRPC_2_0.Response.Payload
            .ErrorPayload(code: try! JSONRPC_2_0.Response.Payload.ErrorPayload.Code(-30_000),
                          message: "failure",
                          data: .array([.int(1), .int(2), .int(3)]))),
                             id: .null)
}
