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
    private var isConnected = false
    // serial queue for receiving the calls.
    private let serialCallbackQueue: DispatchQueue

    var isOpen: Bool {
        return isConnected
    }

    init(url: WCURL,
         onConnect: (() -> Void)?,
         onDisconnect: ((Error?) -> Void)?,
         onTextReceive: ((String) -> Void)?) {
        self.url = url
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
        self.onTextReceive = onTextReceive
        serialCallbackQueue = DispatchQueue(label: "org.walletconnect.swift.connection-\(url.bridgeURL)-\(url.topic)")
        var request = URLRequest(url: URL(string: url.bridgeURL.absoluteString)!)
        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        socket.delegate = self
        socket.callbackQueue = serialCallbackQueue
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
        if let request = try? requestSerializer.deserialize(text, url: url).json().string {
            LogService.shared.log("WC: ==> \(request)")
        } else if let response = try? responseSerializer.deserialize(text, url: url).json().string {
            LogService.shared.log("WC: ==> \(response)")
        } else {
            LogService.shared.log("WC: ==> \(text)")
        }
    }
}

extension WebSocketConnection: WebSocketDelegate {
    
    // MARK: - WebSocketDelegate
     func didReceive(event: WebSocketEvent, client: WebSocket) {
         switch event {
         case .connected(let headers):
             isConnected = true
             print("websocket is connected: \(headers)")
         case .disconnected(let reason, let code):
             isConnected = false
             print("websocket is disconnected: \(reason) with code: \(code)")
         case .text(let string):
             print("Received text: \(string)")
         case .binary(let data):
             print("Received data: \(data.count)")
         case .ping(_):
             break
         case .pong(_):
             break
         case .viabilityChanged(_):
             break
         case .reconnectSuggested(_):
             break
         case .cancelled:
             isConnected = false
         case .error(let error):
             isConnected = false
             handleError(error)
         }
     }
     
     func handleError(_ error: Error?) {
         if let e = error as? WSError {
             print("websocket encountered an error: \(e.message)")
         } else if let e = error {
             print("websocket encountered an error: \(e.localizedDescription)")
         } else {
             print("websocket encountered an error")
         }
     }
    
    func websocketDidConnect(socket: WebSocketClient) {
        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            LogService.shared.log("WC: ==> ping")
            self?.socket.write(ping: Data())
        }
        onConnect?()
    }

    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        pingTimer?.invalidate()
        onDisconnect?(error)
    }

    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        onTextReceive?(text)
    }

    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        // no-op
    }
}
