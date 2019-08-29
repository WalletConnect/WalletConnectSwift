//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import WalletConnectSwift

class WalletConnectTests: XCTestCase {

    var wc = WalletConnect()
    let mockCommunicator = MockCommunicator()

    override func setUp() {
        super.setUp()
        wc.communicator = mockCommunicator
    }

    func test_whenConnectingToNewURL_thenConnects() {
        XCTAssertFalse(mockCommunicator.didListen)
        try? wc.connect(to: WCURL.testURL)
        XCTAssertTrue(mockCommunicator.didListen)
    }

    func test_whenConnectingToExistingURL_thenThrows() {
        mockCommunicator.addSession(Session.testSession)
        XCTAssertThrowsError(try wc.connect(to: WCURL.testURL))
    }

    func test_whenReconnecting_thenConnects() {
        XCTAssertFalse(mockCommunicator.didListen)
        try? wc.reconnect(to: Session.testSession)
        XCTAssertTrue(mockCommunicator.didListen)
        let addedSession = mockCommunicator.session(by: Session.testSession.url)
        XCTAssertEqual(addedSession, Session.testSession)
    }

    func test_whenReconnectingToSessionWithoutWalletInfo_thenThrows() {
        XCTAssertThrowsError(try wc.reconnect(to: Session.testSessionWithoutWalletInfo))
    }

}
