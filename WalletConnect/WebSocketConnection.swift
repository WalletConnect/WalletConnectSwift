//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation
import Starscream

class WebSocketConnection {

    private (set) var url: WCURL
    private var socket: WebSocket
    private var messageHandler: ((String) -> Void)?

    init(url: WCURL) {
        self.url = url
        socket = WebSocket(url: url.bridgeURL)
    }

    func open() {
        socket.connect()
    }

    func close() {
        socket.disconnect()
    }

    func receive(_ completion: @escaping (String) -> Void) {
        assert(messageHandler == nil, "Assuming that receive is called once")
        messageHandler = completion
    }

    func send(_ text: String) {
        socket.write(string: text)
    }

}

extension WebSocketConnection: WebSocketDelegate {

    func websocketDidConnect(socket: WebSocketClient) {

    }

    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {

    }

    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        messageHandler?(text)
    }

    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {

    }


}
