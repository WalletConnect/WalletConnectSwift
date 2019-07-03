//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import MultisigWalletImplementations

class SessionTests: XCTestCase {

    func test_canCreateSessionFromRequest() throws {
        let JSONPRCRequest = try JSONRPC_2_0.Request.create(from: JSONRPC_2_0.JSON(WCSessionRequest.json))
        let url = WCURL(bridgeURL: URL(string: "https://test.com")!, topic: "topic", key: "key")
        let request = Request(payload: JSONPRCRequest, url: url)
        let session = try Session(wcSessionRequest: request)!
        XCTAssertEqual(session.url, url)
        XCTAssertEqual(session.peerId, "Slow.Trade")
        XCTAssertEqual(session.clientMeta.description, "Good trades take time")
        XCTAssertEqual(session.clientMeta.url, URL(string: "https://slow.trade")!)
        XCTAssertEqual(session.clientMeta.icons, [URL(string: "https://example.com/1.png")!,
                                                  URL(string: "https://example.com/2.png")!])
        XCTAssertEqual(session.clientMeta.name, "Slow Trade")
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
