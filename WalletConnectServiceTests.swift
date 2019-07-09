//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import MultisigWalletImplementations
import MultisigWalletDomainModel
import CommonTestSupport

// swiftlint:disable weak_delegate
class WalletConnectServiceTests: XCTestCase {

    var service: WalletConnectService!
    fileprivate var server: MockServer!
    fileprivate let delegate = MockWalletConnectDelegate()
    let url = "wc:id1@1?bridge=https%3A%2F%2Fbridge.walletconnect.org&key=key"

    override func setUp() {
        super.setUp()
        service = WalletConnectService(delegate: delegate)
        server = MockServer(delegate: service)
        service.server = server
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
        server.delegate.server(server, didFailToConnect: MultisigWalletImplementations
            .WCURL(wcURL: MultisigWalletDomainModel.WCURL.testURL))
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

}

extension MultisigWalletDomainModel.WCURL {

    static let testURL = MultisigWalletDomainModel.WCURL(topic: "topic1",
                                                         version: "1",
                                                         bridgeURL: URL(string: "http://test.com")!,
                                                         key: "key")

}

extension WCClientMeta {

    static let testMeta = WCClientMeta(name: "name",
                                       description: "description",
                                       icons: [],
                                       url: URL(string: "http://test.com")!)

}

extension WCDAppInfo {

    static let testDAppInfo = WCDAppInfo(peerId: "peer1", peerMeta: WCClientMeta.testMeta)

}

extension WCWalletInfo {

    static let testWalletInfo = WCWalletInfo(approved: true,
                                             accounts: [],
                                             chainId: 1,
                                             peerId: "peer1",
                                             peerMeta: WCClientMeta.testMeta)

}

extension WCSession {

    static let testSession = WCSession(url: MultisigWalletDomainModel.WCURL.testURL,
                                       dAppInfo: WCDAppInfo.testDAppInfo,
                                       walletInfo: WCWalletInfo.testWalletInfo,
                                       status: .connected)

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

}
