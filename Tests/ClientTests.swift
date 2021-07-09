//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import WalletConnectSwift

class ClientTests: XCTestCase {
    var client: Client!
    let delegate = MockClientDelegate()
    let communicator = MockCommunicator()

    override func setUp() {
        super.setUp()
        client = Client(delegate: delegate, dAppInfo: Session.DAppInfo.testDappInfo)
        client.communicator = communicator
    }

    func test_sendRequest_whenSessionNotFound_thenThrows() {
        XCTAssertThrowsError(try client.send(Request.testRequest, completion: nil), "sessionNotFound") { error in
            XCTAssertEqual(error as? Client.ClientError, .sessionNotFound)
        }
    }

    func test_sendRequest_whenNoWalletInfo_thenThrows() {
        communicator.addSession(Session.testSessionWithoutWalletInfo)
        XCTAssertThrowsError(try client.send(Request.testRequest, completion: nil),
                             "missingWalletInfoInSession") { error in
                                XCTAssertEqual(error as? Client.ClientError, .missingWalletInfoInSession)
        }
    }

    func test_sendRequest_callsCommunicator() {
        communicator.addSession(Session.testSession)
        try? client.send(Request.testRequest, completion: nil)
        XCTAssertNotNil(communicator.sentRequest)
    }

    func test_personal_sign_callsCommunicator() {
        let account = prepareAccountWithTestSession()
        try! client.personal_sign(url: WCURL.testURL, message: "Hi there", account:  account) { _ in }
        XCTAssertNotNil(communicator.sentRequest)
    }

    func test_eth_sign_callsCommunicator() {
        let account = prepareAccountWithTestSession()
        try! client.eth_sign(url: WCURL.testURL, account: account, message: "smth") { _ in }
        XCTAssertNotNil(communicator.sentRequest)
    }

    func test_eth_signTypedData_callsCommunicator() {
        let account = prepareAccountWithTestSession()
        try! client.eth_signTypedData(url: WCURL.testURL, account: account, message: "smth") { _ in }
        XCTAssertNotNil(communicator.sentRequest)
    }

    func test_eth_sendTransaction_callsCommunicator() {
        prepareAccountWithTestSession()
        try! client.eth_sendTransaction(url: WCURL.testURL, transaction: Client.Transaction.testTransaction) { _ in }
        XCTAssertNotNil(communicator.sentRequest)
    }

    func test_eth_signTransaction_callsCommunicator() {
        prepareAccountWithTestSession()
        try! client.eth_signTransaction(url: WCURL.testURL, transaction: Client.Transaction.testTransaction) { _ in }
        XCTAssertNotNil(communicator.sentRequest)
    }

    @discardableResult
    private func prepareAccountWithTestSession() -> String {
        communicator.addSession(Session.testSession)
        return Session.testSession.walletInfo!.accounts[0]
    }

    func test_onConnect_whenSessionExists_thenSubscribesOnDappPeerIdTopic() {
        communicator.addSession(Session.testSession)
        client.onConnect(to: WCURL.testURL)
        XCTAssertEqual(communicator.subscribedOn?.topic, Session.testSession.dAppInfo.peerId)
        XCTAssertEqual(communicator.subscribedOn?.url, Session.testSession.url)
    }

    func test_onConnect_callsDelegate() {
        XCTAssertNil(delegate.connectedUrl)
        client.onConnect(to: WCURL.testURL)
        XCTAssertEqual(delegate.connectedUrl, WCURL.testURL)
    }

    func test_onConnect_whenSessionExists_thenCallsDelegate() {
        communicator.addSession(Session.testSession)
        XCTAssertNil(delegate.connectedSession)
        client.onConnect(to: WCURL.testURL)
        XCTAssertEqual(delegate.connectedSession, Session.testSession)
    }

    func test_onConnect_whenHandshakeInProcess_thenSubscribesOnDappPeerIdTopic() {
        client.onConnect(to: WCURL.testURL)
        XCTAssertEqual(communicator.subscribedOn?.topic, Session.DAppInfo.testDappInfo.peerId)
        XCTAssertEqual(communicator.subscribedOn?.url, WCURL.testURL)
    }

    func test_onConnect_whenHandshakeInProcess_thenCallsCommunicator() {
        client.onConnect(to: WCURL.testURL)
        XCTAssertNotNil(communicator.sentRequest)
    }
}

class MockClientDelegate: ClientDelegate {
    var didFailToConnect = false
    func client(_ client: Client, didFailToConnect url: WCURL) {
        didFailToConnect = true
    }

    var connectedUrl: WCURL?
    func client(_ client: Client, didConnect url: WCURL) {
        connectedUrl = url
    }

    var connectedSession: Session?
    func client(_ client: Client, didConnect session: Session) {
        connectedSession = session
    }

    var disconnectedSession: Session?
    func client(_ client: Client, didDisconnect session: Session) {
        disconnectedSession = session
    }

    var didUpdateSession: Session?
    func client(_ client: Client, didUpdate session: Session) {
        didUpdateSession = session
    }
}
