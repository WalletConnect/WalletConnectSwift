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
        case tryingToDisconnectInactiveSession
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

    /// Disconnect from session.
    ///
    /// - Parameter session: Session object
    /// - Throws: error on trying to disconnect inacative sessoin.
    public func disconnect(from session: Session) throws {
        guard communicator.isConnected(by: session.url) else {
            throw WalletConnectError.tryingToDisconnectInactiveSession
        }
        try sendDisconnectSessionRequest(for: session)
        communicator.addPendingDisconnectSession(session)
        communicator.disconnect(from: session.url)
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

    func sendDisconnectSessionRequest(for session: Session) throws {
        preconditionFailure("Should be implemented in subclasses")
    }

    func failedToConnect(_ url: WCURL) {
        preconditionFailure("Should be implemented in subclasses")
    }

    func didDisconnect(_ session: Session) {
        preconditionFailure("Should be implemented in subclasses")
    }

    func log(_ request: Request) {
        guard let text = try? request.payload.json().string else { return }
        print("WC: <== \(text)")
    }

    func log(_ response: Response) {
        guard let text = try? response.payload.json().string else { return }
        print("WC: <== \(text)")
    }

}

extension JSONRPC_2_0.Response {

    typealias PayloadCode = JSONRPC_2_0.Response.Payload.ErrorPayload.Code

    static func errorPayload(code: PayloadCode, message: String) -> JSONRPC_2_0.Response.Payload.ErrorPayload {
        return JSONRPC_2_0.Response.Payload.ErrorPayload(code: code, message: message, data: nil)
    }

    static func methodDoesNotExistError(id: JSONRPC_2_0.IDType?) -> JSONRPC_2_0.Response {
        let message = "The method does not exist / is not available."
        return JSONRPC_2_0.Response(result: .error(errorPayload(code: PayloadCode.methodNotFound,
                                                                message: message)),
                                    id: id ?? .null)
    }

    static let invalidJSON =
        JSONRPC_2_0.Response(result: .error(errorPayload(code: PayloadCode.invalidJSON,
                                                         message: "Invalid JSON was received by the server.")),
                             id: JSONRPC_2_0.IDType.null)

}
