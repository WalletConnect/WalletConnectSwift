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

    /// Called only when the session is disconnect with intention of the dApp or the Wallet.
    func server(_ server: Server, didDisconnect session: Session, error: Error?)

}

public class Server {

    private let transport: Transport
    private let responseSerializer: ResponseSerializer
    private let requestSerializer: RequestSerializer

    // server session are the approved connections between dApp and Wallet
    private let sessions: Sessions

    // triggered by Wallet or dApp to disconnect
    private let pendingDisconnectSessions: Sessions

    private let handlers: Handlers

    private(set) weak var delegate: ServerDelegate!

    // serial queue to guard access to handlers, sessions, and pendingSessions
    private let syncQueue = DispatchQueue(label: "org.walletconnect.swift.server")

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
        sessions = Sessions(queue: syncQueue)
        pendingDisconnectSessions = Sessions(queue: syncQueue)
        handlers = Handlers(queue: syncQueue)
        register(handler: HandshakeHandler(delegate: self))
        register(handler: UpdateSessionHandler(delegate: self))
    }

    public func register(handler: RequestHandler) {
        handlers.add(handler)
    }

    public func unregister(handler: RequestHandler) {
        handlers.remove(handler)
    }

    /// Connect to WalletConnect url
    /// https://docs.walletconnect.org/tech-spec#requesting-connection
    ///
    /// - Parameter url: WalletConnect url
    /// - Throws: error on trying to connect to existing session url
    public func connect(to url: WCURL) throws {
        guard sessions.find(url: url) == nil else {
            throw ServerError.tryingToConnectExistingSessionURL
        }
        listen(on: url)
    }

    /// Reconnect to the session
    ///
    /// - Parameter session: session object with wallet info.
    /// - Throws: error if wallet info is missing
    public func reconnect(to session: Session) throws {
        guard session.walletInfo != nil else {
            throw ServerError.missingWalletInfoInSession
        }
        sessions.add(session)
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
        return sessions.all().filter { transport.isConnected(by: $0.url) }
    }

    /// Disconnect from session.
    ///
    /// - Parameter session: Session object
    /// - Throws: error on trying to disconnect inacative sessoin.
    public func disconnect(from session: Session) throws {
        guard transport.isConnected(by: session.url) else {
            throw ServerError.tryingToDisconnectInactiveSession
        }
        try updateSession(session, with: session.walletInfo!.with(approved: false))
        pendingDisconnectSessions.add(session)
        transport.disconnect(from: session.url)
    }

    /// Update session with new wallet info.
    ///
    /// - Parameters:
    ///   - session: Session object
    ///   - walletInfo: WalletInfo object
    /// - Throws: error if wallet info is missing
    public func updateSession(_ session: Session, with walletInfo: Session.WalletInfo) throws {
        guard session.walletInfo != nil else {
            throw ServerError.missingWalletInfoInSession
        }
        // TODO: where to handle error?
        let request = try! UpdateSessionRequest(url: session.url, walletInfo: walletInfo)!
        send(request)
    }

    // TODO: where to handle error?
    public func send(_ response: Response) {
        guard let session = sessions.find(url: response.url) else { return }
        send(response, topic: session.dAppInfo.peerId)
    }

    private func send(_ response: Response, topic: String) {
        let text = try! responseSerializer.serialize(response, topic: topic)
        transport.send(to: response.url, text: text)
    }

    // TODO: where to handle error?
    public func send(_ request: Request) {
        guard let session = sessions.find(url: request.url) else { return }
        let text = try! requestSerializer.serialize(request, topic: session.dAppInfo.peerId)
        transport.send(to: request.url, text: text)
    }

    /// Process incomming text messages from the transport layer.
    ///
    /// - Parameters:
    ///   - text: incoming message
    ///   - url: WalletConnect url
    private func onTextReceive(_ text: String, from url: WCURL) {
        do {
            // we handle only properly formed JSONRPC 2.0 requests. JSONRPC 2.0 responses are ignored.
            let request = try requestSerializer.deserialize(text, url: url)
            log(request)
            handle(request)
        } catch {
            print("WC: incomming text deserialization to JSONRPC 2.0 requests error: \(error.localizedDescription)")
            send(Response(payload: JSONRPC_2_0.Response.invalidJSON, url: url))
        }
    }

    private func log(_ request: Request) {
        guard let text = try? request.payload.json().string else { return }
        print("WC: <== \(text)")
    }

    /// Confirmation from Transport layer that connection was successfully established.
    ///
    /// - Parameter url: WalletConnect url
    private func onConnect(to url: WCURL) {
        print("WC: didConnect url: \(url.bridgeURL.absoluteString)")
        if let session = sessions.find(url: url) { // reconnecting existing session
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
        guard let session = sessions.find(url: url) else {
            delegate.server(self, didFailToConnect: url)
            return
        }
        // if a session was not initiated by the wallet or the dApp to disconnect, try to reconnect it.
        guard pendingDisconnectSessions.find(url: url) != nil else {
            // TODO: should we notify delegate that we try to reconnect?
            print("WC: trying to reconnect session by url: \(url.bridgeURL.absoluteString)")
            try! reconnect(to: session)
            return
        }
        sessions.remove(url: url)
        pendingDisconnectSessions.remove(url: url)
        delegate.server(self, didDisconnect: session, error: error)
    }

    private func handle(_ request: Request) {
        if let handler = handlers.find(by: request) {
            handler.handle(request: request)
        } else {
            let payload = JSONRPC_2_0.Response.methodDoesNotExistError(id: request.payload.id)
            send(Response(payload: payload, url: request.url))
        }
    }

    // TODO: where to handle error?
    private func subscribe(on topic: String, url: WCURL) {
        let message = PubSubMessage(topic: topic, type: .sub, payload: "")
        transport.send(to: url, text: try! message.json())
    }

    /// Thread-safe collection of Sessions
    private class Sessions {

        private var sessions: [WCURL: Session] = [:]
        private let queue: DispatchQueue

        init(queue: DispatchQueue) {
            self.queue = queue
        }

        func add(_ session: Session) {
            queue.sync { [unowned self] in
                self.sessions[session.url] = session
            }
        }

        func all() -> [Session] {
            var result: [Session] = []
            queue.sync { [unowned self] in
                result = Array(self.sessions.values)
            }
            return result
        }

        func find(url: WCURL) -> Session? {
            var result: Session?
            queue.sync { [unowned self] in
                result = self.sessions[url]
            }
            return result
        }

        func remove(url: WCURL) {
            queue.sync { [unowned self] in
                _ = self.sessions.removeValue(forKey: url)
            }
        }

    }

    /// thread-safe collection of RequestHandlers
    private class Handlers {

        private var handlers: [RequestHandler] = []
        private var queue: DispatchQueue

        init(queue: DispatchQueue) {
            self.queue = queue
        }

        func add(_ handler: RequestHandler) {
            queue.sync { [unowned self] in
                guard self.handlers.first(where: { $0 === handler }) == nil else { return }
                self.handlers.append(handler)
            }
        }

        func remove(_ handler: RequestHandler) {
            queue.sync { [unowned self] in
                if let index = self.handlers.firstIndex(where: { $0 === handler }) {
                    self.handlers.remove(at: index)
                }
            }
        }

        func find(by request: Request) -> RequestHandler? {
            var result: RequestHandler?
            queue.sync { [unowned self] in
                result = self.handlers.first { $0.canHandle(request: request) }
            }
            return result
        }

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
                sessions.add(updatedSession)
                subscribe(on: walletInfo.peerId, url: updatedSession.url)
                delegate.server(self, didConnect: updatedSession)
            }
        }
    }

}

extension Server: UpdateSessionHandlerDelegate {

    func handler(_ handler: UpdateSessionHandler, didUpdateSessionByURL url: WCURL, approved: Bool) {
        guard let session = sessions.find(url: url) else { return }
        if !approved {
            do {
                try disconnect(from: session)
            } catch { // session already disconnected
                delegate.server(self, didDisconnect: session, error: nil)
            }
        }
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
