//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

protocol Transport {

    func send(to url: WCURL, text: String)
    func listen(on url: WCURL,
                onConnect: @escaping ((WCURL) -> Void),
                onDisconnect: @escaping ((WCURL, Error?) -> Void),
                onTextReceive: @escaping (String, WCURL) -> Void)
    func disconnect(from url: WCURL)

}

// future: if we received response from another peer - then we call request.completion() for pending request.
// future: if request is not notification - then it will be pending for response

class Bridge: Transport {

    // TODO: threading. Modifying connections on a serial queue.
    private var connections: [WebSocketConnection] = []

    // TODO: if no connection found, then what?
    func send(to url: WCURL, text: String) {
        if let connection = findConnection(url: url) {
            connection.send(text)
        }
    }

    func listen(on url: WCURL,
                onConnect: @escaping ((WCURL) -> Void),
                onDisconnect: @escaping ((WCURL, Error?) -> Void),
                onTextReceive: @escaping (String, WCURL) -> Void) {
        var connection: WebSocketConnection
        if let existingConnection = findConnection(url: url) {
            connection = existingConnection
        } else {
            connection = WebSocketConnection(url: url,
                                             onConnect: { onConnect(url) },
                                             onDisconnect: { error in onDisconnect(url, error) },
                                             onTextReceive: { text in onTextReceive(text, url) })
            connections.append(connection)
        }
        connection.open()
    }

    func disconnect(from url: WCURL) {
        if let connection = findConnection(url: url) {
            connection.close()
            connections.removeAll { $0 === connection }
        }
    }

    private func findConnection(url: WCURL) -> WebSocketConnection? {
        return connections.first { $0.url == url }
    }

}
