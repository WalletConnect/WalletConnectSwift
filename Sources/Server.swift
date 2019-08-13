//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

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
    func server(_ server: Server, didDisconnect session: Session)

}

public class Server: WalletConnect {

    private let handlers: Handlers
    private(set) weak var delegate: ServerDelegate!

    enum ServerError: Error {
        case missingWalletInfoInSession
    }

    public init(delegate: ServerDelegate) {
        self.delegate = delegate
        handlers = Handlers(queue: DispatchQueue(label: "org.walletconnect.swift.server.handlers"))
        super.init()
        register(handler: HandshakeHandler(delegate: self))
        register(handler: UpdateSessionHandler(delegate: self))
    }

    public func register(handler: RequestHandler) {
        handlers.add(handler)
    }

    public func unregister(handler: RequestHandler) {
        handlers.remove(handler)
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
        let request = try! UpdateSessionRequest(url: session.url, walletInfo: walletInfo)!
        send(request)
    }

    // TODO: where to handle error?
    public func send(_ response: Response) {
        guard let session = communicator.session(by: response.url) else { return }
        communicator.send(response, topic: session.dAppInfo.peerId)
    }

    // TODO: where to handle error?
    public func send(_ request: Request) {
        guard let session = communicator.session(by: request.url) else { return }
        communicator.send(request, topic: session.dAppInfo.peerId)
    }

    override func onTextReceive(_ text: String, from url: WCURL) {
        do {
            // we handle only properly formed JSONRPC 2.0 requests. JSONRPC 2.0 responses are ignored.
            let request = try communicator.request(from: text, url: url)
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

    override func onConnect(to url: WCURL) {
        print("WC: didConnect url: \(url.bridgeURL.absoluteString)")
        if let session = communicator.session(by: url) { // reconnecting existing session
            communicator.subscribe(on: session.walletInfo!.peerId, url: session.url)
            delegate.server(self, didConnect: session)
        } else { // establishing new connection, handshake in process
            communicator.subscribe(on: url.topic, url: url)
        }
    }

    private func handle(_ request: Request) {
        if let handler = handlers.find(by: request) {
            handler.handle(request: request)
        } else {
            let payload = JSONRPC_2_0.Response.methodDoesNotExistError(id: request.payload.id)
            send(Response(payload: payload, url: request.url))
        }
    }

    override func sendDisconnectSessionRequest(for session: Session) throws {
        guard let walletInfo = session.walletInfo else {
            throw ServerError.missingWalletInfoInSession
        }
        try updateSession(session, with: walletInfo.with(approved: false))
    }

    override func failedToConnect(_ url: WCURL) {
        delegate.server(self, didFailToConnect: url)
    }

    override func didDisconnect(_ session: Session) {
        delegate.server(self, didDisconnect: session)
    }

    /// thread-safe collection of RequestHandlers
    private class Handlers {

        private var handlers: [RequestHandler] = []
        private var queue: DispatchQueue

        init(queue: DispatchQueue) {
            self.queue = queue
        }

        func add(_ handler: RequestHandler) {
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [unowned self] in
                guard self.handlers.first(where: { $0 === handler }) == nil else { return }
                self.handlers.append(handler)
            }
        }

        func remove(_ handler: RequestHandler) {
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [unowned self] in
                if let index = self.handlers.firstIndex(where: { $0 === handler }) {
                    self.handlers.remove(at: index)
                }
            }
        }

        func find(by request: Request) -> RequestHandler? {
            var result: RequestHandler?
            dispatchPrecondition(condition: .notOnQueue(queue))
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
            communicator.send(sessionCreationResponse, topic: session.dAppInfo.peerId)
            if walletInfo.approved {
                let updatedSession = Session(url: session.url, dAppInfo: session.dAppInfo, walletInfo: walletInfo)
                communicator.addSession(updatedSession)
                communicator.subscribe(on: walletInfo.peerId, url: updatedSession.url)
                delegate.server(self, didConnect: updatedSession)
            }
        }
    }

}

extension Server: UpdateSessionHandlerDelegate {

    func handler(_ handler: UpdateSessionHandler, didUpdateSessionByURL url: WCURL, approved: Bool) {
        guard let session = communicator.session(by: url) else { return }
        if !approved {
            do {
                try disconnect(from: session)
            } catch { // session already disconnected
                delegate.server(self, didDisconnect: session)
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
