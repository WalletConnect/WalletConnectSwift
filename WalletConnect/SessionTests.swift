//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import MultisigWalletImplementations

class SessionTests: XCTestCase {

    let url = WCURL("wc:topic@1?bridge=https%3A%2F%2Ftest.com&key=key")!
    let walletId = UUID().uuidString

    func test_canCreateSessionFromRequest() throws {
        let session = try createSession()
        XCTAssertEqual(session.url, url)
        XCTAssertEqual(session.dAppInfo.peerId, "Slow.Trade")
        XCTAssertEqual(session.dAppInfo.peerMeta.description, "Good trades take time")
        XCTAssertEqual(session.dAppInfo.peerMeta.url, URL(string: "https://slow.trade")!)
        XCTAssertEqual(session.dAppInfo.peerMeta.icons, [URL(string: "https://example.com/1.png")!,
                                                         URL(string: "https://example.com/2.png")!])
        XCTAssertEqual(session.dAppInfo.peerMeta.name, "Slow Trade")
        XCTAssertNil(session.walletInfo)
    }

    func test_creationResponse() throws {
        let session = try createSession()
        let info = Session.WalletInfo(approved: true,
                                      accounts: ["0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95"],
                                      chainId: 1,
                                      peerId: walletId,
                                      peerMeta: Session.ClientMeta(name: "Gnosis Safe",
                                                                   description: "Secure Wallet",
                                                                   icons: [URL(string: "https://example.com/1.png")!],
                                                                   url: URL(string: "gnosissafe://")!))
        let response = session.creationResponse(requestId: .int(100), walletInfo: info)
        XCTAssertEqual(response.url, session.url)
        XCTAssertEqual(response.payload.id, .int(100))
        XCTAssertEqual(response.payload.result,
                       .value(.object(["approved": .bool(true),
                                       "accounts": .array([.string("0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95")]),
                                       "chainId": .int(1),
                                       "peerId": .string(walletId),
                                       "peerMeta": .object(["name": .string("Gnosis Safe"),
                                                            "description": .string("Secure Wallet"),
                                                            "icons": .array([.string("https://example.com/1.png")]),
                                                            "url": .string("gnosissafe://")])])))
    }

    private func createSession() throws -> Session {
        let JSONPRCRequest = try JSONRPC_2_0.Request.create(from: JSONRPC_2_0.JSON(WCSessionRequest.json))
        let request = Request(payload: JSONPRCRequest, url: url)
        return try Session(wcSessionRequest: request)!
    }

}

fileprivate enum WCSessionRequest {

    static let json = """
{
    "id": 100,
    "jsonrpc": "2.0",
    "method": "wc_sessionRequest",
    "params": [
        {
            "peerId": "Slow.Trade",
            "peerMeta": {
                "description": "Good trades take time",
                "url": "https://slow.trade",
                "icons": ["https://example.com/1.png", "https://example.com/2.png"],
                "name": "Slow Trade"
            }
        }
    ]
}
"""
}
