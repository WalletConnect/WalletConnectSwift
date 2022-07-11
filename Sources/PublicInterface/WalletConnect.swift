//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

open class WalletConnect {
    var communicator = Communicator()

    public init() {}

    public enum WalletConnectError: Error {
        case tryingToConnectExistingSessionURL
        case tryingToDisconnectInactiveSession
        case missingWalletInfoInSession
    }

    /// Connect to WalletConnect url
    /// https://docs.walletconnect.org/tech-spec#requesting-connection
    ///
    /// - Parameter url: WalletConnect url
    /// - Throws: error on trying to connect to existing session url
    open func connect(to url: WCURL) throws {
        guard communicator.session(by: url) == nil else {
            throw WalletConnectError.tryingToConnectExistingSessionURL
        }
        listen(on: url)
    }

    /// Reconnect to the session
    ///
    /// - Parameter session: session object with wallet info.
    /// - Throws: error if wallet info is missing
    open func reconnect(to session: Session) throws {
        guard session.walletInfo != nil else {
            throw WalletConnectError.missingWalletInfoInSession
        }
        communicator.addOrUpdateSession(session)
        listen(on: session.url)
    }

    /// Disconnect from session.
    ///
    /// - Parameter session: Session object
    /// - Throws: error on trying to disconnect inacative sessoin.
    open func disconnect(from session: Session) throws {
        guard communicator.isConnected(by: session.url) else {
            throw WalletConnectError.tryingToDisconnectInactiveSession
        }
        try sendDisconnectSessionRequest(for: session)
        communicator.addOrUpdatePendingDisconnectSession(session)
        communicator.disconnect(from: session.url)
    }

    /// Get all sessions with active connection.
    ///
    /// - Returns: sessions list.
    open func openSessions() -> [Session] {
        return communicator.openSessions()
    }

    private func listen(on url: WCURL) {
        let onConnect: ((WCURL) -> Void) = { [weak self] url in
            self?.onConnect(to: url)
        }
        let onDisconnect: ((WCURL, Error?) -> Void) = { [weak self] (url, error) in
            self?.onDisconnect(from: url, error: error)
        }
        let onTextReceive: ((String, WCURL) -> Void) = { [weak self] (text, url) in
            self?.onTextReceive(text, from: url)
        }
        communicator.listen(on: url,
                            onConnect: onConnect,
                            onDisconnect: onDisconnect,
                            onTextReceive: onTextReceive)
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
        LogService.shared.log("WC: didDisconnect url: \(url.bridgeURL.absoluteString)")
        // check if disconnect happened during handshake
        guard let session = communicator.session(by: url) else {
            failedToConnect(url)
            return
        }
        // if a session was not initiated by the wallet or the dApp to disconnect, try to reconnect it.
        guard communicator.pendingDisconnectSession(by: url) != nil else {
            LogService.shared.log("WC: trying to reconnect session by url: \(url.bridgeURL.absoluteString)")
            willReconnect(session)
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

    func sendDisconnectSessionRequest(for session: Session) throws {
        preconditionFailure("Should be implemented in subclasses")
    }

    func failedToConnect(_ url: WCURL) {
        preconditionFailure("Should be implemented in subclasses")
    }

    func didDisconnect(_ session: Session) {
        preconditionFailure("Should be implemented in subclasses")
    }

    func willReconnect(_ session: Session) {
        preconditionFailure("Should be implemented in subclasses")
    }

    func log(_ request: Request) {
        guard let text = try? request.json().string else { return }
        LogService.shared.log("WC: <== [request] \(text)")
    }

    func log(_ response: Response) {
        guard let text = try? response.json().string else { return }
        LogService.shared.log("WC: <== [response] \(text)")
    }
}
