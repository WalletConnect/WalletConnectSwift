//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation
import MultisigWalletDomainModel

public class WalletConnectService: WalletConnectDomainService {

    var server: Server!
    private weak var delegate: WalletConnectDomainServiceDelegate!

    public init(delegate: WalletConnectDomainServiceDelegate) {
        server = Server(delegate: self)
        self.delegate = delegate
    }

    public func connect(url: String) throws {
        guard let wcurl = WCURL(url) else { throw WCError.wrongURLFormat }
        do {
            try server.connect(to: wcurl)
        } catch {
            throw WCError.tryingToConnectExistingSessionURL
        }
    }

    public func reconnect(session: WCSession) throws {
        do {
            try server.reconnect(to: Session(wcSession: session))
        } catch {
            throw WCError.wrongSessionFormat
        }
    }

    public func disconnect(session: WCSession) throws {
        do {
            try server.disconnect(from: Session(wcSession: session))
        } catch {
            throw WCError.tryingToDisconnectInactiveSession
        }
    }

    public func openSessions() -> [WCSession] {
        return server.openSessions().map { $0.wcSession(status: .connected) }
    }

}

extension WalletConnectService: ServerDelegate {

    public func server(_ server: Server, didFailToConnect url: WCURL) {
        delegate.didFailToConnect(url: url.wcURL)
    }

    public func server(_ server: Server, shouldStart session: Session, completion: (Session.WalletInfo) -> Void) {
        delegate.shouldStart(session: session.wcSession(status: .connecting)) { wcWalletInfo in
            completion(Session.WalletInfo(wcWalletInfo: wcWalletInfo))
        }
    }

    public func server(_ server: Server, didConnect session: Session) {
        delegate.didConnect(session: session.wcSession(status: .connected))
    }

    public func server(_ server: Server, didDisconnect session: Session, error: Error?) {
        delegate.didDisconnect(session: session.wcSession(status: .disconnected))
    }

}

extension WCURL {

    init(wcURL: MultisigWalletDomainModel.WCURL) {
        self.init(topic: wcURL.topic, version: wcURL.version, bridgeURL: wcURL.bridgeURL, key: wcURL.key)
    }

    var wcURL: MultisigWalletDomainModel.WCURL {
        return MultisigWalletDomainModel.WCURL(topic: topic, version: version, bridgeURL: bridgeURL, key: key)
    }

}

extension Session.ClientMeta {

    init(wcClientMeta: WCClientMeta) {
        self.init(name: wcClientMeta.name,
                  description: wcClientMeta.description,
                  icons: wcClientMeta.icons,
                  url: wcClientMeta.url)
    }

    var wcClientMeta: WCClientMeta {
        return WCClientMeta(name: name, description: description, icons: icons, url: url)
    }

}

extension Session.DAppInfo {

    init(wcDAppInfo: WCDAppInfo) {
        self.init(peerId: wcDAppInfo.peerId, peerMeta: Session.ClientMeta(wcClientMeta: wcDAppInfo.peerMeta))
    }

    var wcDAppInfo: WCDAppInfo {
        return WCDAppInfo(peerId: peerId, peerMeta: peerMeta.wcClientMeta)
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

    var wcWalletInfo: WCWalletInfo {
        return WCWalletInfo(approved: approved,
                            accounts: accounts,
                            chainId: chainId,
                            peerId: peerId,
                            peerMeta: peerMeta.wcClientMeta)
    }

}

extension Session {

    init(wcSession: WCSession) {
        self.init(url: WCURL(wcURL: wcSession.url),
                  dAppInfo: DAppInfo(wcDAppInfo: wcSession.dAppInfo),
                  walletInfo: Session.WalletInfo(wcWalletInfo: wcSession.walletInfo))
    }

    func wcSession(status: WCSessionStatus) -> WCSession {
        return WCSession(url: url.wcURL,
                         dAppInfo: dAppInfo.wcDAppInfo,
                         walletInfo: walletInfo!.wcWalletInfo,
                         status: status)
    }

}
