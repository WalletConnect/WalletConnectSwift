//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

public class WalletConnect {

    let communicator: Communicator

    init() {
        communicator = Communicator()
    }

    enum WalletConnectError: Error {
        case tryingToConnectExistingSessionURL
        case missingWalletInfoInSession
    }

    /// Connect to WalletConnect url
    /// https://docs.walletconnect.org/tech-spec#requesting-connection
    ///
    /// - Parameter url: WalletConnect url
    /// - Throws: error on trying to connect to existing session url
    public func connect(to url: WCURL) throws {
        guard communicator.session(by: url) == nil else {
            throw WalletConnectError.tryingToConnectExistingSessionURL
        }
        listen(on: url)
    }

    /// Reconnect to the session
    ///
    /// - Parameter session: session object with wallet info.
    /// - Throws: error if wallet info is missing
    public func reconnect(to session: Session) throws {
        guard session.walletInfo != nil else {
            throw WalletConnectError.missingWalletInfoInSession
        }
        communicator.addSession(session)
        listen(on: session.url)
    }

    /// Get all sessions with active connection.
    ///
    /// - Returns: sessions list.
    public func openSessions() -> [Session] {
        return communicator.openSessions()
    }

    private func listen(on url: WCURL) {
        communicator.listen(on: url,
                            onConnect: onConnect(to:),
                            onDisconnect: onDisconnect(from:error:),
                            onTextReceive: onTextReceive(_:from:))
    }

    /// Confirmation from Transport layer that connection was successfully established.
    ///
    /// - Parameter url: WalletConnect url
    func onConnect(to url: WCURL) {
        preconditionFailure("Should be implemented in subclasses")
    }

    //// Confirmation from Transport layer that connection was dropped.
    ///
    /// - Parameters:
    ///   - url: WalletConnect url
    ///   - error: error that triggered the disconnection
    private func onDisconnect(from url: WCURL, error: Error?) {
        print("WC: didDisconnect url: \(url.bridgeURL.absoluteString)")
        // check if disconnect happened during handshake
        guard let session = communicator.session(by: url) else {
            failedToConnect(url)
            return
        }
        // if a session was not initiated by the wallet or the dApp to disconnect, try to reconnect it.
        guard communicator.pendingDisconnectSession(by: url) != nil else {
            // TODO: should we notify delegate that we try to reconnect?
            print("WC: trying to reconnect session by url: \(url.bridgeURL.absoluteString)")
            try! reconnect(to: session)
            return
        }
        communicator.removeSession(by: url)
        communicator.removePendingDisconnectSession(by: url)
        didDisconnect(session)
    }

    /// Process incomming text messages from the transport layer.
    ///
    /// - Parameters:
    ///   - text: incoming message
    ///   - url: WalletConnect url
    func onTextReceive(_ text: String, from url: WCURL) {
        preconditionFailure("Should be implemented in subclasses")
    }

    func failedToConnect(_ url: WCURL) {
        preconditionFailure("Should be implemented in subclasses")
    }

    func didDisconnect(_ session: Session) {
        preconditionFailure("Should be implemented in subclasses")
    }

}
