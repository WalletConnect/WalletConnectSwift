//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

public protocol RequestHandler: AnyObject {
    func canHandle(request: Request) -> Bool
    func handle(request: Request)
}

public protocol ServerDelegate: AnyObject {
    /// Websocket connection was dropped during handshake. The connectoin process should be initiated again.
    func server(_ server: Server, didFailToConnect url: WCURL)

    /// The handshake will be established based on "approved" property of WalletInfo.
    func server(_ server: Server, shouldStart session: Session, completion: @escaping (Session.WalletInfo) -> Void)

    /// Called when the session is connected or reconnected.
    /// Reconnection may happen as a result of Wallet intention to reconnect, or as a result of
    /// the server trying to restore lost connection.
    func server(_ server: Server, didConnect session: Session)

    /// Called only when the session is disconnect with intention of the dApp or the Wallet.
    func server(_ server: Server, didDisconnect session: Session)

    /// Called only when the session is updated with intention of the dAppt.
    func server(_ server: Server, didUpdate session: Session)
}

public protocol ServerDelegateV2: ServerDelegate {
    /// Replacement for the `server(_:shouldStart:completion:) method that makes possible async approval process.
    /// When the approval is ready, call the `Server.sendCreateSessionResponse` method.
    /// If you implement this protocol, the other `shouldStart` method will not be called
    ///
    ///
    /// - Parameters:
    ///   - server: the server object
    ///   - requestId: connection request's id. Can be Int, Double, or String
    ///   - session: the session to create. Contains dapp info received in the connection request.
    func server(_ server: Server, didReceiveConnectionRequest requestId: RequestID, for session: Session)

    /// Called when the session is being reconnected as part of the retry mechanism after the connection
    /// has been lost due to e.g. bad connectivity.
    func server(_ server: Server, willReconnect session: Session)
}

open class Server: WalletConnect {
    private let handlers: Handlers
    public private(set) weak var delegate: ServerDelegate?

    public enum ServerError: Error {
        case missingWalletInfoInSession
        case failedToCreateSessionResponse
    }

    public init(delegate: ServerDelegate) {
        self.delegate = delegate
        handlers = Handlers(queue: DispatchQueue(label: "org.walletconnect.swift.server.handlers"))
        super.init()
        register(handler: HandshakeHandler(delegate: self))
        register(handler: UpdateSessionHandler(delegate: self))
    }

    open func register(handler: RequestHandler) {
        handlers.add(handler)
    }

    open func unregister(handler: RequestHandler) {
        handlers.remove(handler)
    }

    /// Update session with new wallet info.
    ///
    /// - Parameters:
    ///   - session: Session object
    ///   - walletInfo: WalletInfo object
    /// - Throws: error if wallet info is missing
    open func updateSession(_ session: Session, with walletInfo: Session.WalletInfo) throws {
        guard session.walletInfo != nil else {
            throw ServerError.missingWalletInfoInSession
        }
        let request = try Request(url: session.url, method: "wc_sessionUpdate", params: [walletInfo], id: nil)
        send(request)
    }

    // TODO: where to handle error?
    open func send(_ response: Response) {
        guard let session = communicator.session(by: response.url) else { return }
        communicator.send(response, topic: session.dAppInfo.peerId)
    }

    // TODO: where to handle error?
    open func send(_ request: Request) {
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
            LogService.shared.log(
                "WC: incomming text deserialization to JSONRPC 2.0 requests error: \(error.localizedDescription)")
            // TODO: handle error
            try! send(Response(url: url, error: .invalidJSON))
        }
    }

    override func onConnect(to url: WCURL) {
        LogService.shared.log("WC: didConnect url: \(url.bridgeURL.absoluteString)")
        if let session = communicator.session(by: url) { // reconnecting existing session
            communicator.subscribe(on: session.walletInfo!.peerId, url: session.url)
            delegate?.server(self, didConnect: session)
        } else { // establishing new connection, handshake in process
            communicator.subscribe(on: url.topic, url: url)
        }
    }

    private func handle(_ request: Request) {
        if let handler = handlers.find(by: request) {
            handler.handle(request: request)
        } else {
            // TODO: error handling
            let response = try! Response(request: request, error: .methodNotFound)
            send(response)
        }
    }

    override func sendDisconnectSessionRequest(for session: Session) throws {
        guard let walletInfo = session.walletInfo else {
            throw ServerError.missingWalletInfoInSession
        }
        try updateSession(session, with: walletInfo.with(approved: false))
    }

    override func failedToConnect(_ url: WCURL) {
        delegate?.server(self, didFailToConnect: url)
    }

    override func didDisconnect(_ session: Session) {
        delegate?.server(self, didDisconnect: session)
    }

    override func willReconnect(_ session: Session) {
        if let delegate = delegate as? ServerDelegateV2 {
            delegate.server(self, willReconnect: session)
        }
    }

    /// Sends response for the create session request.
    /// Use this method together with `ServerDelegate.server(_ server:didReceiveConnectionRequest:for:)`.
    ///
    /// - Parameters:
    ///   - requestId: pass the request id that was received before
    ///   - session: session with dapp info populated.
    ///   - walletInfo: the response from the wallet.
    ///         If approved, you need to create peerId with UUID().uuidString and put it inside the wallet info.
    public func sendCreateSessionResponse(for requestId: RequestID, session: Session, walletInfo: Session.WalletInfo) {
        let response: Response
        do {
            response = try Response(url: session.url, value: walletInfo, id: requestId)
        } catch {
            LogService.shared.log("WC: failed to compose SessionRequest response: \(error)")
            delegate?.server(self, didFailToConnect: session.url)
            return
        }
        communicator.send(response, topic: session.dAppInfo.peerId)
        if walletInfo.approved {
            let updatedSession = Session(url: session.url, dAppInfo: session.dAppInfo, walletInfo: walletInfo)
            communicator.addOrUpdateSession(updatedSession)
            communicator.subscribe(on: walletInfo.peerId, url: updatedSession.url)
            delegate?.server(self, didConnect: updatedSession)
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
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [weak self] in
                guard let `self` = self else { return }
                guard self.handlers.first(where: { $0 === handler }) == nil else { return }
                self.handlers.append(handler)
            }
        }

        func remove(_ handler: RequestHandler) {
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [weak self] in
                guard let `self` = self else { return }
                if let index = self.handlers.firstIndex(where: { $0 === handler }) {
                    self.handlers.remove(at: index)
                }
            }
        }

        func find(by request: Request) -> RequestHandler? {
            var result: RequestHandler?
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [weak self] in
                guard let `self` = self else { return }
                result = self.handlers.first { $0.canHandle(request: request) }
            }
            return result
        }
    }
}

extension Server: HandshakeHandlerDelegate {
    func handler(_ handler: HandshakeHandler,
                 didReceiveRequestToCreateSession session: Session,
                 requestId: RequestID) {
        guard let delegate = delegate else { return }
        if let delegateV2 = delegate as? ServerDelegateV2 {
            delegateV2.server(self, didReceiveConnectionRequest: requestId, for: session)
        } else {
            delegate.server(self, shouldStart: session) { [weak self] walletInfo in
                guard let `self` = self else {
                    return
                }
                self.sendCreateSessionResponse(for: requestId, session: session, walletInfo: walletInfo)
            }
        }
    }
}

extension Server: UpdateSessionHandlerDelegate {
    func handler(_ handler: UpdateSessionHandler, didUpdateSessionByURL url: WCURL, sessionInfo: SessionInfo) {
        guard let session = communicator.session(by: url) else { return }
        if !sessionInfo.approved {
            self.communicator.addOrUpdatePendingDisconnectSession(session)
            self.communicator.disconnect(from: session.url)
            self.delegate?.server(self, didDisconnect: session)
        } else {
            // we do not add sessions without walletInfo
            let walletInfo = session.walletInfo!
            let updatedInfo = Session.WalletInfo(
                approved: sessionInfo.approved,
                accounts: sessionInfo.accounts ?? [],
                chainId: sessionInfo.chainId ?? ChainID.mainnet,
                peerId: walletInfo.peerId,
                peerMeta: walletInfo.peerMeta
            )
            var updatedSesson = session
            updatedSesson.walletInfo = updatedInfo
            communicator.addOrUpdateSession(updatedSesson)
            delegate?.server(self, didUpdate: updatedSesson)
        }
    }
}
