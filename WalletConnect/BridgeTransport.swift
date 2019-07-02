//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

protocol Transport {

    func send(to url: WCURL, text: String)
    func listen(on url: WCURL, handler: @escaping (String) -> Void)
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

    // Should we send connection onConnect / onDisconnect / onTextReceive to server?
    func listen(on url: WCURL, handler: @escaping (String) -> Void) {
        var connection: WebSocketConnection
        if let existingConnection = findConnection(url: url) {
            connection = existingConnection
        } else {
            connection = WebSocketConnection(url: url,
                                             onConnect: onWebSocketConnect,
                                             onDisconnect: onWebSocketDisconnect,
                                             onTextReceive: handler)
            connections.append(connection)
        }
        connection.open()
    }

    public func disconnect(from url: WCURL) {
        if let connection = findConnection(url: url) {
            connection.close()
            connections.removeAll { $0 === connection }
        }
    }

    private func findConnection(url: WCURL) -> WebSocketConnection? {
        return connections.first { $0.url == url }
    }

    private func onWebSocketConnect() {
        // we should notify server on connect only on successfull handshake
    }

    private func onWebSocketDisconnect(error: Error?) {
        // we should handle handshake and other connections separately
    }

}
