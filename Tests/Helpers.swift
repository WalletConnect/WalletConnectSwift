//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation
@testable import WalletConnectSwift

class MockCommunicator: Communicator {

    private var sessions = [Session]()

    var didListen = false
    override func listen(on url: WCURL,
                         onConnect: @escaping ((WCURL) -> Void),
                         onDisconnect: @escaping ((WCURL, Error?) -> Void),
                         onTextReceive: @escaping (String, WCURL) -> Void) {
        didListen = true
    }

    override func addSession(_ session: Session) {
        sessions.append(session)
    }
    
    override func session(by url: WCURL) -> Session? {
        return sessions.first { $0.url == url }
    }

}

extension WCURL {

    static let testURL = WCURL("wc:test123@1?bridge=https%3A%2F%2Fbridge.walletconnect.org&key=46d8847bdbca255a98ba7d79d4f4d77daebbbeb53b5aea6e9f39fa848b177bb7")!

}

extension Session: Equatable {

    public static func == (lhs: Session, rhs: Session) -> Bool {
        return lhs.dAppInfo == rhs.dAppInfo &&
            lhs.url == rhs.url &&
            lhs.walletInfo == rhs.walletInfo
    }

    static let testSession = Session(url: WCURL.testURL,
                                     dAppInfo: Session.DAppInfo.testDappInfo,
                                     walletInfo: Session.WalletInfo.testWalletInfo)

    static let testSessionWithoutWalletInfo = Session(url: WCURL.testURL,
                                                      dAppInfo: Session.DAppInfo.testDappInfo,
                                                      walletInfo: nil)

}

extension Session.DAppInfo {

    static let testDappInfo = Session.DAppInfo(peerId: "test", peerMeta: Session.ClientMeta.testMeta, approved: true)

}

extension Session.WalletInfo {

    static let testWalletInfo = Session.WalletInfo(approved: true,
                                                   accounts: ["0xCF4140193531B8b2d6864cA7486Ff2e18da5cA95"],
                                                   chainId: 4,
                                                   peerId: "test234",
                                                   peerMeta: Session.ClientMeta.testMeta)
}

extension Session.ClientMeta {

    static let testMeta = Session.ClientMeta(name: "Test Meta",
                                             description: nil,
                                             icons: [],
                                             url: URL(string: "https://walletconnect.org")!)
}
