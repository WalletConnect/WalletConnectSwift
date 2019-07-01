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

struct WCURL {
    var bridgeURL: URL
    var topic: String
    var key: String

    var url: URL!
}

class Request {

    class ID {
        var origin: WCURL! // includes topic and bridge url
        var id: Any? // client-sent request id
    }

    var id: Request.ID! // always set
    var method: String!
    var parameters: Parameters!

    func setOrigin(_ url: WCURL) {
        id.origin = url
    }

    class Parameters { // more of a struct.

        var count: Int!
        var isEmpty: Bool!

        func parameter(at position: Int) -> Any? {
            return nil
        }
        func insert(parameter: Any, at position: Int) {}
        func remove(at position: Int) {}

        func parameter(name: String) -> Any? {
            return nil
        }

        func set(parameter: Any?, for name: String) {}
        func remove(name: String) {}

    }
}

class Response {
    // id must be set even if no request id was recieved - in that case id.origin is set.
    var id: Request.ID!
    var result: Result<Any, Error>!

    var origin: WCURL {
        return id.origin
    }

    func setOrigin(_ url: WCURL) {
        id.origin = origin
    }

    init(id: Request.ID?, result: Result<Any, Error>) {
        self.id = id
        self.result = result
    }
}

enum ServerError: Error {
    case methodNotFound
}

protocol RequestHandler {

    func canHandle(request: Request) -> Bool
    func handle(request: Request)

}

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
        transport.listen(on: url.url) { [unowned self] text in
            self.onIncomingData(text, from: url)
        }
    }

    // TODO: topic forwarding to transport layer

    func disconnect(from url: WCURL) {
        transport.disconnect(from: url.url)
    }

    private func onIncomingData(_ text: String, from url: WCURL) {
        do {
            let request = try requestSerializer.deserialize(text, url: url)
            handle(request)
        } catch {
            send(Response(id: nil, result: .failure(error)))
        }
    }

    private func handle(_ request: Request) {
        if let handler = handlers.first(where: { $0.canHandle(request: request) }) {
            handler.handle(request: request)
        } else {
            send(Response(id: request.id, result: .failure(ServerError.methodNotFound)))
        }
    }

    func send(_ response: Response) {
        // TODO: where to handle error?
        let text = try! responseSerializer.serialize(response)
        transport.send(to: response.origin.url, text: text)
    }

    func send(_ request: Request) {
        // TODO: where to handle error?
        let text = try! requestSerializer.serialize(request)
        transport.send(to: request.id.origin.url, text: text)
    }

}
