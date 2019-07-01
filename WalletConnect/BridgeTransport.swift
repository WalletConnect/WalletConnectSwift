//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

protocol Transport {

    func send(to url: URL, text: String)
    func listen(on url: URL, handler: @escaping (String) -> Void)
    func disconnect(from url: URL)

}

// future: if we received response from another peer - then we call request.completion() for pending request.
// future: if request is not notification - then it will be pending for response

class Bridge: Transport {

    // TODO: threading. Modifying connections on a serial queue.

    private var connections: [WebSocketConnection] = []

    private func addConnection(_ connection: WebSocketConnection) {
        connections.append(connection)
    }

    private func findConnection(url: URL) -> WebSocketConnection? {
        return connections.first { $0.url == url }
    }

    // TODO: if no connection found, then what?

    func send(to url: URL, text: String) {
        if let connection = findConnection(url: url) {
            connection.send(text)
        }
    }

    // TODO: if there exists connection - then what?

    func listen(on url: URL, handler: @escaping (String) -> Void) {
        // url -> bridge endpoint
        let connection = WebSocketConnection(url: url)
        addConnection(connection)
        connection.open()
        connection.receive(handler)
    }

    func disconnect(from url: URL) {
        if let connection = findConnection(url: url) {
            connection.close()
        }
    }

}
