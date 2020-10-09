//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import WalletConnectSwift

class SessionTests: XCTestCase {
    let url = WCURL("wc:topic@1?bridge=https%3A%2F%2Ftest.com&key=key")!
    let walletId = UUID().uuidString

    func test_canCreateSessionFromRequest() throws {
        let session = try createServerSession()
        XCTAssertEqual(session.url, url)
        XCTAssertEqual(session.dAppInfo.peerId, "Slow.Trade ID")
        XCTAssertEqual(session.dAppInfo.peerMeta.description, "Good trades take time")
        XCTAssertEqual(session.dAppInfo.peerMeta.url, URL(string: "https://slow.trade")!)
        XCTAssertEqual(session.dAppInfo.peerMeta.icons, [URL(string: "https://example.com/1.png")!,
                                                         URL(string: "https://example.com/2.png")!])
        XCTAssertEqual(session.dAppInfo.peerMeta.name, "Slow Trade")
        XCTAssertNil(session.walletInfo)
    }

    func test_canCreateSessionFromResponse() throws {
        let session = try createClientSession()
        XCTAssertNotNil(session.dAppInfo)
        XCTAssertEqual(session.url, url)
        XCTAssertEqual(session.walletInfo?.approved, true)
        XCTAssertEqual(session.walletInfo?.accounts, ["0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95"])
        XCTAssertEqual(session.walletInfo?.chainId, 4)
        XCTAssertEqual(session.walletInfo?.peerId, "Gnosis Safe ID")
        XCTAssertEqual(session.walletInfo?.peerMeta?.name, "Gnosis Safe")
        XCTAssertEqual(session.walletInfo?.peerMeta?.url, URL(string: "https://safe.gnosis.io")!)
        XCTAssertEqual(session.walletInfo?.peerMeta?.icons, [URL(string: "https://example.com/1.png")!,
                                                            URL(string: "https://example.com/2.png")!])
        XCTAssertEqual(session.walletInfo?.peerMeta?.description, "Secure 2FA Wallet")
    }

    func test_creationResponse() throws {
        let session = try createServerSession()
        let info = Session.WalletInfo(approved: true,
                                      accounts: ["0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95"],
                                      chainId: 1,
                                      peerId: walletId,
                                      peerMeta: Session.ClientMeta(name: "Gnosis Safe",
                                                                   description: "Secure Wallet",
                                                                   icons: [URL(string: "https://example.com/1.png")!],
                                                                   url: URL(string: "gnosissafe://")!))
        let response = try Response(url: session.url, value: info, id: 100)
        XCTAssertEqual(response.url, session.url)
        XCTAssertEqual(response.internalID, .int(100))

        let resultInfo = try response.result(as: Session.WalletInfo.self)
        XCTAssertEqual(resultInfo, info)
    }

    private func createServerSession() throws -> Session {
        let JSONPRCRequest = try JSONRPC_2_0.Request.create(from: JSONRPC_2_0.JSON(WCSessionRequest.json))
        let request = Request(payload: JSONPRCRequest, url: url)
        let dappInfo = try! request.parameter(of: Session.DAppInfo.self, at: 0)
        let session = Session(url: request.url, dAppInfo: dappInfo, walletInfo: nil)
        return session
    }

    private func createClientSession() throws -> Session {
        let JSONPRCResponse = try JSONRPC_2_0.Response.create(from: JSONRPC_2_0.JSON(WCSessionResponse.json))
        let response = Response(payload: JSONPRCResponse, url: url)
        let dAppInfo = Session.DAppInfo(peerId: "Slow.Trade ID",
                                        peerMeta: Session.ClientMeta(name: "Slow Trade",
                                                                     description: "Good trades take time",
                                                                     icons: [URL(string: "https://example.com/1.png")!],
                                                                     url: URL(string: "https://slow.trade")!))
        let walletInfo = try response.result(as: [Session.WalletInfo].self)
        return Session(url: url, dAppInfo: dAppInfo, walletInfo: walletInfo[0])
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
            "peerId": "Slow.Trade ID",
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

fileprivate enum WCSessionResponse {
    static let json = """
{
    "id": 100,
    "jsonrpc": "2.0",
    "result": [
        {
            "peerId": "Gnosis Safe ID",
            "peerMeta": {
                "description": "Secure 2FA Wallet",
                "url": "https://safe.gnosis.io",
                "icons": ["https://example.com/1.png", "https://example.com/2.png"],
                "name": "Gnosis Safe"
            },
            "approved": true,
            "chainId": 4,
            "accounts": ["0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95"]
        }
    ]
}
"""
}
