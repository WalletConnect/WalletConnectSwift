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

    func server(_ server: Server, shouldStart session: Session, completion: (Session.WalletInfo) -> Void)
    func server(_ server: Server, didConnect session: Session)
    func server(_ server: Server, didDisconnect session: Session, error: Error?)

}

public class Server {

    private var transport: Transport
    private var responseSerializer: ResponseSerializer
    private var requestSerializer: RequestSerializer
    private var handlers: [RequestHandler] = []
    // server session are the approved connections between dApp and Wallet
    private var sessions = [WCURL: Session]()

    private(set) weak var delegate: ServerDelegate!

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

    public func connect(to url: WCURL) {
        transport.listen(on: url,
                         onConnect: onConnect(to:),
                         onDisconnect: onDisconnect(from:error:),
                         onTextReceive: onTextReceive(_:from:))
    }

    // TODO: topic forwarding to transport layer

    func disconnect(from url: WCURL) {
        transport.disconnect(from: url)
    }

    /// Process incomming text messages from the transport layer.
    ///
    /// - Parameters:
    ///   - text: incoming message
    ///   - url: WalletConnect url
    private func onTextReceive(_ text: String, from url: WCURL) {
        do {
            print("WC: incomming text: \(text)")
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
        subscribe(on: url.topic, url: url)
        print("WC: didConnect url: \(url.description)")
    }

    /// Confirmation from Transport layer that connection was dropped.
    ///
    /// - Parameters:
    ///   - url: WalletConnect url
    ///   - error: error that triggered the disconnection
    private func onDisconnect(from url: WCURL, error: Error?) {
        if let session = sessions[url] {
            sessions.removeValue(forKey: url)
            delegate.server(self, didDisconnect: session, error: error)
        }
        print("WC: didDisconnect url: \(url.description); error: \(error.debugDescription)")
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

    // TODO: where to handle error?
    public func send(_ response: Response) {
        guard let session = sessions[response.url] else { return }
        let text = try! responseSerializer.serialize(response, topic: session.dAppInfo.peerId)
        transport.send(to: response.url, text: text)
    }

    // TODO: where to handle error?
    public func send(_ request: Request) {
        guard let session = sessions[request.url] else { return }
        let text = try! requestSerializer.serialize(request, topic: session.dAppInfo.peerId)
        transport.send(to: request.url, text: text)
    }

}

extension Server: HandshakeHandlerDelegate {

    func handler(_ handler: HandshakeHandler,
                 didReceiveRequestToCreateSession session: Session,
                 requestId: JSONRPC_2_0.IDType) {
        delegate.server(self, shouldStart: session) { walletInfo in
            // it is safer to subscribe before sending the response
            if walletInfo.approved {
                subscribe(on: walletInfo.peerId, url: session.url)
            }
            // session mapping should exist to send the response
            sessions[session.url] = session
            let sessionCreationResponse = session.creationResponse(requestId: requestId, walletInfo: walletInfo)
            send(sessionCreationResponse)
            if !walletInfo.approved {
                sessions.removeValue(forKey: session.url)
            }
            delegate.server(self, didConnect: session)
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
