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
    // needed to keep connection alive
    private var pingTimer: Timer?
    // TODO: make injectable on server creation
    private let pingInterval: TimeInterval = 30

    private var requestSerializer: RequestSerializer = JSONRPCSerializer()
    private var responseSerializer: ResponseSerializer = JSONRPCSerializer()

    var isOpen: Bool {
        return socket.isConnected
    }

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
        guard socket.isConnected else { return }
        socket.write(string: text)
        log(text)
    }

    private func log(_ text: String) {
        if let request = try? requestSerializer.deserialize(text, url: url).payload.json().string {
            print("WC: ==> \(request)")
        } else if let response = try? responseSerializer.deserialize(text, url: url).payload.json().string {
            print("WC: ==> \(response)")
        } else {
            print("WC: ==> \(text)")
        }
    }

}

extension WebSocketConnection: WebSocketDelegate {

    func websocketDidConnect(socket: WebSocketClient) {
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            print("WC: ==> ping")
            self?.socket.write(ping: Data())
        }
        DispatchQueue.global.async {
            self.onConnect?()
        }
    }

    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        pingTimer?.invalidate()
        DispatchQueue.global.async {
            self.onDisconnect?(error)
        }
    }

    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        DispatchQueue.global.async {
            self.onTextReceive?(text)
        }
    }

    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        // no-op
    }

}
