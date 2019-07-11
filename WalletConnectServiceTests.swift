//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import MultisigWalletImplementations
import MultisigWalletDomainModel
import CommonTestSupport
import Common

// swiftlint:disable weak_delegate
class WalletConnectServiceTests: XCTestCase {

    var service: WalletConnectService!
    fileprivate var server: MockServer!
    fileprivate let delegate = MockWalletConnectDelegate()
    let url = "wc:id1@1?bridge=https%3A%2F%2Fbridge.walletconnect.org&key=key"
    let logger = MockLogger()

    override func setUp() {
        super.setUp()
        service = WalletConnectService()
        service.updateDelegate(delegate)
        server = MockServer(delegate: service)
        service.server = server
        DomainRegistry.put(service: logger, for: Logger.self)
    }

    func test_whenConnecting_thenCallsServer() throws {
        try service.connect(url: url)
        XCTAssertEqual(server.connectUrl?.topic, "id1")
        XCTAssertEqual(server.connectUrl?.version, "1")
        XCTAssertEqual(server.connectUrl?.bridgeURL, URL(string: "https://bridge.walletconnect.org"))
        XCTAssertEqual(server.connectUrl?.key, "key")
    }

    func test_whenConnectingWithWrongURL_thenProperErrorIsThrown() {
        XCTAssertThrowsError(try service.connect(url: "some")) {
            XCTAssertTrue($0 as? WCError == WCError.wrongURLFormat)
        }
    }

    func test_whenConnectingThrows_thenProperErrorIsThrown() {
        server.shouldThrow = true
        XCTAssertThrowsError(try service.connect(url: url)) {
            XCTAssertTrue($0 as? WCError == WCError.tryingToConnectExistingSessionURL)
        }
    }

    func test_whenReconnecting_thenCallsServer() throws {
        try service.reconnect(session: WCSession.testSession)
        XCTAssertEqual(server.reconnectSession?.url.topic, "topic1")
        XCTAssertEqual(server.reconnectSession?.url.version, "1")
        XCTAssertEqual(server.reconnectSession?.url.bridgeURL, URL(string: "http://test.com"))
        XCTAssertEqual(server.reconnectSession?.url.key, "key")
    }

    func test_whenReconnectingThrows_thenProperErrorIsThrown() {
        server.shouldThrow = true
        XCTAssertThrowsError(try service.reconnect(session: WCSession.testSession)) {
            XCTAssertTrue($0 as? WCError == WCError.wrongSessionFormat)
        }
    }

    func test_whenDisconnecting_thenCallsServer() throws {
        try service.disconnect(session: WCSession.testSession)
        XCTAssertNotNil(server.disconnectSession)
    }

    func test_whenDisconnectingThrows_thenProperErrorIsThrown() {
        server.shouldThrow = true
        XCTAssertThrowsError(try service.disconnect(session: WCSession.testSession)) {
            XCTAssertTrue($0 as? WCError == WCError.tryingToDisconnectInactiveSession)
        }
    }

    func test_openSessions_returnsOpenServerSessions() {
        server.sessions = [Session(wcSession: WCSession.testSession)]
        XCTAssertEqual(service.openSessions(), [WCSession.testSession])
    }

    func test_whenServerFailsToConnect_thenDelegateCalled() {
        let url = MultisigWalletImplementations.WCURL(wcURL: MultisigWalletDomainModel.WCURL.testURL)
        server.delegate.server(server, didFailToConnect: url)
        XCTAssertNotNil(delegate.failedURLToConnect)
    }

    func test_whenServerShouldStartSession_thenDelegateCalled() {
        server.delegate.server(server, shouldStart: Session(wcSession: WCSession.testSession)) { _ in }
        XCTAssertNotNil(delegate.shouldStartSession)
    }

    func test_whenServerDidConnect_thenDelegateCalled() {
        server.delegate.server(server, didConnect: Session(wcSession: WCSession.testSession))
        XCTAssertNotNil(delegate.connectedSession)
    }

    func test_whenServerDidDisconnect_thenDelegateCalled() {
        server.delegate.server(server, didDisconnect: Session(wcSession: WCSession.testSession), error: nil)
        XCTAssertNotNil(delegate.disconnectedSession)
    }

    func test_whenHandlingSendTransactionRequest_thenDelegateCalled() throws {
        service.handle(request: request(from: MockRequestPayload.sendTransaction))
        XCTAssertEqual(delegate.sendTransactionRequest!.from, "0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95")
        XCTAssertEqual(delegate.sendTransactionRequest!.to, "0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95")
        XCTAssertEqual(delegate.sendTransactionRequest!.gasLimit, "0x5208")
        XCTAssertEqual(delegate.sendTransactionRequest!.gasPrice, "0x3b9aca00")
        XCTAssertEqual(delegate.sendTransactionRequest!.value, "0x00")
        XCTAssertEqual(delegate.sendTransactionRequest!.data, "0x")
        XCTAssertEqual(delegate.sendTransactionRequest!.nonce, "0x00")
    }

    func test_whenHandlingInvalidRequest_thenErrorIsLogged() throws {
        service.handle(request: request(from: MockRequestPayload.sendTransactionInvalid))
        XCTAssertTrue(logger.errorLogged)
    }

    func test_whenHandlingEthereumNodeRequest_thenDelegateCalled() {
        service.handle(request: request(from: MockRequestPayload.personalSignRequest))
        XCTAssertNotNil(delegate.ethereumNodeRequest)
    }

    private func request(from json: String) -> Request {
        let jsonRPCRequest = try! JSONRPC_2_0.Request.create(from: JSONRPC_2_0.JSON(json))
        let url = MultisigWalletImplementations.WCURL(wcURL: MultisigWalletDomainModel.WCURL.testURL)
        return Request(payload: jsonRPCRequest, url: url)
    }

}

fileprivate class MockServer: Server {

    var shouldThrow = false

    var connectUrl: MultisigWalletImplementations.WCURL?
    override func connect(to url: MultisigWalletImplementations.WCURL) throws {
        if shouldThrow { throw TestError.error }
        connectUrl = url
    }

    var reconnectSession: Session?
    override func reconnect(to session: Session) throws {
        if shouldThrow { throw TestError.error }
        reconnectSession = session
    }

    var disconnectSession: Session?
    override func disconnect(from session: Session) throws {
        if shouldThrow { throw TestError.error }
        disconnectSession = session
    }

    var sessions = [Session]()
    override func openSessions() -> [Session] {
        return sessions
    }

}

fileprivate class MockWalletConnectDelegate: WalletConnectDomainServiceDelegate {

    var failedURLToConnect: MultisigWalletDomainModel.WCURL?
    func didFailToConnect(url: MultisigWalletDomainModel.WCURL) {
        failedURLToConnect = url
    }

    var shouldStartSession: WCSession?
    func shouldStart(session: WCSession, completion: (WCWalletInfo) -> Void) {
        shouldStartSession = session
    }

    var connectedSession: WCSession?
    func didConnect(session: WCSession) {
        connectedSession = session
    }

    var disconnectedSession: WCSession?
    func didDisconnect(session: WCSession) {
        disconnectedSession = session
    }

    var sendTransactionRequest: WCSendTransactionRequest?
    func handleSendTransactionRequest(_ request: WCSendTransactionRequest,
                                      completion: @escaping (Result<String, Error>) -> Void) {
        sendTransactionRequest = request
    }

    var ethereumNodeRequest: WCMessage?
    func handleEthereumNodeRequest(_ request: WCMessage, completion: (Result<WCMessage, Error>) -> Void) {
        ethereumNodeRequest = request
    }

}

fileprivate class MockRequestPayload {

    static let sendTransaction = """
{"jsonrpc":"2.0","method":"eth_sendTransaction","id":1562744955028827,
"params":[{"from":"0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95","data":"0x","gasLimit":"0x5208","value":"0x00",
"to":"0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95","gasPrice":"0x3b9aca00","nonce":"0x00"}]}
"""

    static let sendTransactionInvalid = """
{"jsonrpc":"2.0","method":"eth_sendTransaction","id":1562744955028827,
"params":{"from":"0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95","data":"0x","gasLimit":"0x5208","value":"0x00",
"to":"0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95","gasPrice":"0x3b9aca00","nonce":"0x00"}}
"""

    static let personalSignRequest = """
{"jsonrpc":"2.0","method":"personal_sign","id":1562748678643280,
"params":["0x4d7920656d61696c206973206a6f686e40646f652e636f6d202d2031353337383336323036313031",
"0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95"]}
"""

}
