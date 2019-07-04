//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation
import Starscream

class WebSocketConnection {

    let url: WCURL
    private let socket: WebSocket
    private let onConnect: (() -> Void)?
    private let onDisconnect: ((Error?) -> Void)?
    private let onTextReceive: ((String) -> Void)?

    init(url: WCURL,
         onConnect: (() -> Void)?,
         onDisconnect: ((Error?) -> Void)?,
         onTextReceive: ((String) -> Void)?) {
        self.url = url
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
        self.onTextReceive = onTextReceive
        socket = WebSocket(url: url.bridgeURL)
        socket.delegate = self
    }

    func open() {
        socket.connect()
    }

    func close() {
        socket.disconnect()
    }

    func send(_ text: String) {
        socket.write(string: text)
        print("WC: WebSocket write: \(text)")
    }

}

extension WebSocketConnection: WebSocketDelegate {

    func websocketDidConnect(socket: WebSocketClient) {
        onConnect?()
    }

    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        onDisconnect?(error)
    }

    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        onTextReceive?(text)
    }

    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        // no-op
    }


}
