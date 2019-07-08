//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation
import MultisigWalletDomainModel

public class WalletConnectService: WalletConnectDomainService {

    private var server: Server!

    public init() {
        server = Server(delegate: self)
    }

    public func connect(url: String) throws {
        guard let wcurl = WCURL(url) else { throw WCError.wrongURLFormat }
        do {
            try server.connect(to: wcurl)
        } catch {
            throw WCError.tryingToConnectExistingSessionURL
        }
    }

    public func reconnect(session: WCSession) throws {}

    public func disconnect(session: WCSession) throws {

    }

    public func activeSessions() -> [WCSession] {
        return []
    }

}

extension WalletConnectService: ServerDelegate {

    public func server(_ server: Server, didFailToConnect url: WCURL) {

    }

    public func server(_ server: Server, shouldStart session: Session, completion: (Session.WalletInfo) -> Void) {

    }

    public func server(_ server: Server, didConnect session: Session) {

    }

    public func server(_ server: Server, didDisconnect session: Session, error: Error?) {

    }

}

extension WCURL {

    init(wcURL: MultisigWalletDomainModel.WCURL) {
        self.init(topic: wcURL.topic, version: wcURL.version, bridgeURL: wcURL.bridgeURL, key: wcURL.key)
    }

}

extension Session.ClientMeta {

    init(wcClientMeta: WCClientMeta) {
        self.init(name: wcClientMeta.name,
                  description: wcClientMeta.description,
                  icons: wcClientMeta.icons,
                  url: wcClientMeta.url)
    }

}

extension Session.DAppInfo {

    init(wcDAppInfo: WCDAppInfo) {
        self.init(peerId: wcDAppInfo.peerId, peerMeta: Session.ClientMeta(wcClientMeta: wcDAppInfo.peerMeta))
    }

}

extension Session.WalletInfo {

    init(wcWalletInfo: WCWalletInfo) {
        self.init(approved: wcWalletInfo.approved,
                  accounts: wcWalletInfo.accounts,
                  chainId: wcWalletInfo.chainId,
                  peerId: wcWalletInfo.peerId,
                  peerMeta: Session.ClientMeta(wcClientMeta: wcWalletInfo.peerMeta))
    }

}

extension Session {

    init(wcSession: WCSession) {
        self.init(url: WCURL(wcURL: wcSession.url),
                  dAppInfo: DAppInfo(wcDAppInfo: wcSession.dAppInfo),
                  walletInfo: Session.WalletInfo(wcWalletInfo: wcSession.walletInfo))
    }

}
