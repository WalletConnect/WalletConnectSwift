//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

public class Request {

    public var payload: JSONRPC_2_0.Request
    public var url: WCURL

    public init(payload: JSONRPC_2_0.Request, url: WCURL) {
        self.payload = payload
        self.url = url
    }

}

public class Response {

    public var payload: JSONRPC_2_0.Response
    public var url: WCURL

    public init(payload: JSONRPC_2_0.Response, url: WCURL) {
        self.payload = payload
        self.url = url
    }

}

public protocol RequestHandler: class {

    func canHandle(request: Request) -> Bool
    func handle(request: Request)

}

public protocol ServerDelegate: class {

    /// Websocket connection was dropped during handshake. The connectoin process should be initiated again.
    func server(_ server: Server, didFailToConnect url: WCURL)

    /// The handshake will be established based on "approved" property of WalletInfo.
    func server(_ server: Server, shouldStart session: Session, completion: (Session.WalletInfo) -> Void)

    /// Called when the session is connected or reconnected.
    /// Reconnection may happen as a result of Wallet intention to reconnect, or as a result of
    /// the server trying to restore lost connection.
    func server(_ server: Server, didConnect session: Session)

    /// called only when the session is disconnect with intention of the dApp or the Wallet.
    func server(_ server: Server, didDisconnect session: Session, error: Error?)

}

public class Server {

    private var transport: Transport
    private var responseSerializer: ResponseSerializer
    private var requestSerializer: RequestSerializer
    private var handlers: [RequestHandler] = []
    // server session are the approved connections between dApp and Wallet
    private var sessions = [WCURL: Session]()
    // triggered by Wallet to disconnect
    private var pendingDisconnectionSessions = [WCURL: Session]()

    private(set) weak var delegate: ServerDelegate!

    enum ServerError: Error {
        case tryingToConnectExistingSessionURL
        case missingWalletInfoInSession
        case tryingToDisconnectInactiveSession
    }

    public init(delegate: ServerDelegate) {
        self.delegate = delegate
        transport = Bridge()
        let serializer = JSONRPCSerializer()
        responseSerializer = serializer
        requestSerializer = serializer
        register(handler: HandshakeHandler(delegate: self))
    }

    public func register(handler: RequestHandler) {
        guard handlers.first(where: { $0 === handler }) == nil else { return }
        handlers.append(handler)
    }

    public func unregister(handler: RequestHandler) {
        if let index = handlers.firstIndex(where: { $0 === handler }) {
            handlers.remove(at: index)
        }
    }

    /// Connect to WalletConnect url
    /// https://docs.walletconnect.org/tech-spec#requesting-connection
    ///
    /// - Parameter url: WalletConnect url
    /// - Throws: error on trying to connect to existing session url
    public func connect(to url: WCURL) throws {
        guard sessions[url] == nil else {
            throw ServerError.tryingToConnectExistingSessionURL
        }
        listen(on: url)
    }

    /// Re-connect to the session
    ///
    /// - Parameter session: session object with wallet info.
    /// - Throws: error if wallet info is missing
    public func reConnect(to session: Session) throws {
        guard session.walletInfo != nil else {
            throw ServerError.missingWalletInfoInSession
        }
        sessions[session.url] = session
        listen(on: session.url)
    }

    private func listen(on url: WCURL) {
        transport.listen(on: url,
                         onConnect: onConnect(to:),
                         onDisconnect: onDisconnect(from:error:),
                         onTextReceive: onTextReceive(_:from:))
    }

    /// Get all sessions with active connection.
    ///
    /// - Returns: sessions list.
    public func openSessions() -> [Session] {
        return Array(sessions.values).filter { transport.isConnected(by: $0.url) }
    }

    /// Disconnect from session.
    ///
    /// - Parameter session: Session object
    /// - Throws: error on trying to disconnect inacative sessoin.
    public func disconnect(from session: Session) throws {
        guard transport.isConnected(by: session.url) else {
            throw ServerError.tryingToDisconnectInactiveSession
        }
        pendingDisconnectionSessions[session.url] = session
        transport.disconnect(from: session.url)
    }

    // TODO: where to handle error?
    public func send(_ response: Response) {
        guard let session = sessions[response.url] else { return }
        send(response, topic: session.dAppInfo.peerId)
    }

    private func send(_ response: Response, topic: String) {
        let text = try! responseSerializer.serialize(response, topic: topic)
        transport.send(to: response.url, text: text)
    }

    // TODO: where to handle error?
    public func send(_ request: Request) {
        guard let session = sessions[request.url] else { return }
        let text = try! requestSerializer.serialize(request, topic: session.dAppInfo.peerId)
        transport.send(to: request.url, text: text)
    }

    /// Process incomming text messages from the transport layer.
    ///
    /// - Parameters:
    ///   - text: incoming message
    ///   - url: WalletConnect url
    private func onTextReceive(_ text: String, from url: WCURL) {
        print("WC: <== \(text)")
        do {
            // we handle only properly formed JSONRPC 2.0 requests. JSONRPC 2.0 responses are ignored.
            let request = try requestSerializer.deserialize(text, url: url)
            handle(request)
        } catch {
            print("WC: incomming text deserialization to JSONRPC 2.0 requests error: \(error.localizedDescription)")
            send(Response(payload: JSONRPC_2_0.Response.invalidJSON, url: url))
        }
    }

    /// Confirmation from Transport layer that connection was successfully established.
    ///
    /// - Parameter url: WalletConnect url
    private func onConnect(to url: WCURL) {
        print("WC: didConnect url: \(url.bridgeURL.absoluteString)")
        if let session = sessions[url] { // reconnecting existing session
            subscribe(on: session.walletInfo!.peerId, url: session.url)
            delegate.server(self, didConnect: session)
        } else { // establishing new connection, handshake in process
            subscribe(on: url.topic, url: url)
        }
    }

    /// Confirmation from Transport layer that connection was dropped by the dApp.
    ///
    /// - Parameters:
    ///   - url: WalletConnect url
    ///   - error: error that triggered the disconnection
    private func onDisconnect(from url: WCURL, error: Error?) {
        print("WC: didDisconnect url: \(url.bridgeURL.absoluteString)")
        // check if disconnect happened during handshake
        guard let session = sessions[url] else {
            delegate.server(self, didFailToConnect: url)
            return
        }
        // if a session was not initiated by the wallet or the dApp to disconnect, try to reconnect it.
        guard let pendingSession = pendingDisconnectionSessions[url] else {
            print("WC: trying to reconnect session by url: \(url.bridgeURL.absoluteString)")
            try! reConnect(to: session)
            return
        }
        sessions.removeValue(forKey: url)
        pendingDisconnectionSessions.removeValue(forKey: url)
        delegate.server(self, didDisconnect: session, error: error)
    }

    private func handle(_ request: Request) {
        if let handler = handlers.first(where: { $0.canHandle(request: request) }) {
            handler.handle(request: request)
        } else {
            send(Response(payload: JSONRPC_2_0.Response.methodDoesNotExist, url: request.url))
        }
    }

    // TODO: where to handle error?
    private func subscribe(on topic: String, url: WCURL) {
        let message = PubSubMessage(topic: topic, type: .sub, payload: "")
        transport.send(to: url, text: try! message.json())
    }

}

extension Server: HandshakeHandlerDelegate {

    func handler(_ handler: HandshakeHandler,
                 didReceiveRequestToCreateSession session: Session,
                 requestId: JSONRPC_2_0.IDType) {
        delegate.server(self, shouldStart: session) { walletInfo in
            let sessionCreationResponse = session.creationResponse(requestId: requestId, walletInfo: walletInfo)
            send(sessionCreationResponse, topic: session.dAppInfo.peerId)
            if walletInfo.approved {
                let updatedSession = Session(url: session.url, dAppInfo: session.dAppInfo, walletInfo: walletInfo)
                sessions[updatedSession.url] = updatedSession
                subscribe(on: walletInfo.peerId, url: updatedSession.url)
                delegate.server(self, didConnect: updatedSession)
            }
        }
    }

}

extension JSONRPC_2_0.Response {

    typealias PayloadCode = JSONRPC_2_0.Response.Payload.ErrorPayload.Code

    static func errorPayload(code: PayloadCode, message: String) -> JSONRPC_2_0.Response.Payload.ErrorPayload {
        return JSONRPC_2_0.Response.Payload.ErrorPayload(code: code, message: message, data: nil)
    }

    static let methodDoesNotExist =
        JSONRPC_2_0.Response(result: .error(errorPayload(code: PayloadCode.methodNotFound,
                                                         message: "The method does not exist / is not available.")),
                             id: JSONRPC_2_0.IDType.null)

    static let invalidJSON =
        JSONRPC_2_0.Response(result: .error(errorPayload(code: PayloadCode.invalidJSON,
                                                         message: "Invalid JSON was received by the server.")),
                             id: JSONRPC_2_0.IDType.null)

}
