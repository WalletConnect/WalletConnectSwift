//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

public struct Session {

    public var url: WCURL
    public var peerId: String?
    public var clientMeta: ClientMeta?

    public struct ClientMeta {

        var name: String
        var description: String
        var icons: [URL]
        var url: URL

    }

    public struct Info {

        public var accounts: [String]
        public var chainID: Int

    }

}

public struct WCURL: Hashable {

    public var bridgeURL: URL
    public var topic: String
    public var key: String

}

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

//enum ServerError: Error {
//    case methodNotFound
//}

public protocol RequestHandler: class {

    func canHandle(request: Request) -> Bool
    func handle(request: Request)

}

public protocol ServerDelegate: class {

    func server(_ server: Server, shouldStart session: Session, completion: (Result<Session.Info, Error>) -> Void)
    func server(_ server: Server, didConnect session: Session)
    func server(_ server: Server, didDisconnect session: Session, error: Error?)

}

// TODO: server should send to bridge onConnect / onDisconnect / onTextReceive handlers and to handle them properly.
// we should understand if this is a handshake connection or if this is a dapp connection and to handle it properly.
public class Server {

    private var transport: Transport
    private var responseSerializer: ResponseSerializer
    private var requestSerializer: RequestSerializer
    private var handlers: [RequestHandler] = []

    private(set) weak var delegate: ServerDelegate!

    public init(delegate: ServerDelegate) {
        self.delegate = delegate
        transport = Bridge()
        let serializer = JSONRPCSerializer()
        responseSerializer = serializer
        requestSerializer = serializer
        
        register(handler: WCHandshakeHandler(delegate: self))
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
        transport.listen(on: url) { [unowned self] text in
            self.onIncomingData(text, from: url)
        }
    }

    // TODO: topic forwarding to transport layer

    func disconnect(from url: WCURL) {
        transport.disconnect(from: url)
    }

    /// Process incomming text messages from the transport layer.
    ///
    /// - Parameters:
    ///   - text: incoming message
    ///   - url: WalletConnect url with information necessary to process incoming message.
    private func onIncomingData(_ text: String, from url: WCURL) {
        do {
            let request = try requestSerializer.deserialize(text, url: url)
            handle(request)
        } catch {
            send(Response(payload: JSONRPC_2_0.Response.invalidJSON, url: url))
        }
    }

    private func handle(_ request: Request) {
        if let handler = handlers.first(where: { $0.canHandle(request: request) }) {
            handler.handle(request: request)
        } else {
            send(Response(payload: JSONRPC_2_0.Response.methodDoesNotExist, url: request.url))
        }
    }

    func send(_ response: Response) {
        // TODO: where to handle error?
        let text = try! responseSerializer.serialize(response)
        transport.send(to: response.url, text: text)
    }

    func send(_ request: Request) {
        // TODO: where to handle error?
        let text = try! requestSerializer.serialize(request)
        transport.send(to: request.url, text: text)
    }

}

extension Server: WCHandshakeHandlerDelegate {

    func handler(_ handler: WCHandshakeHandler, didEstablishHandshake: Bool) {
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
