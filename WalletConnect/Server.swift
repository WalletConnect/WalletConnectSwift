//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

protocol ServerDelegate {
    func server(_ server: Server, shouldStart session: Session, completion: (Result<Session.Info, Error>) -> Void)
    func server(_ server: Server, didConnect session: Session)
    func server(_ server: Server, didDisconnect session: Session, error: Error?)
}

struct Session {

    var url: WCURL
    var peerId: String?
    var clientMeta: ClientMeta?

    struct ClientMeta {
        var name: String
        var description: String
        var icons: [URL]
        var url: URL
    }

    struct Info {
        var accounts: [String]
        var chainID: Int
    }

}

public struct WCURL: Hashable {

    var bridgeURL: URL
    var topic: String
    var key: String

}

public class Request {

    var payload: JSONRPC_2_0.Request
    var url: WCURL

    init(payload: JSONRPC_2_0.Request, url: WCURL) {
        self.payload = payload
        self.url = url
    }

}

public class Response {

    var payload: JSONRPC_2_0.Response
    var url: WCURL

    public init(payload: JSONRPC_2_0.Response, url: WCURL) {
        self.payload = payload
        self.url = url
    }

}

enum ServerError: Error {
    case methodNotFound
}

protocol RequestHandler {

    func canHandle(request: Request) -> Bool
    func handle(request: Request)

}

// public
class Server {

    private var transport: Transport!
    private var responseSerializer: ResponseSerializer!
    private var requestSerializer: RequestSerializer!
    private var handlers: [RequestHandler] = []

    init(delegate: ServerDelegate) {}

    func register(handler: RequestHandler) {}

    func unregister(handler: RequestHandler) {}

    func connect(to session: Session) {
        // if session has peer id - use it!
        // and just connect(to: url)
    }

    func connect(to url: WCURL) {
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
