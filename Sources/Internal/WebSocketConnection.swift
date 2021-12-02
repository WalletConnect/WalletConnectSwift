//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation
import Starscream

class WebSocketConnection {
    let url: WCURL
    private var isConnected: Bool = false
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
    
    // serial queue for receiving the calls.
    private let serialCallbackQueue: DispatchQueue
    
    var isOpen: Bool {
        return self.isConnected
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
        var request = URLRequest(url: url.bridgeURL)
        self.socket = WebSocket(request: request, engine: WSEngine(transport: FoundationTransport(), certPinner: FoundationSecurity()))
        self.socket.callbackQueue = serialCallbackQueue
        self.socket.delegate = self
        
    }
    
    func open() {
        socket.connect()
    }
    
    func close(closeCode: UInt16 = CloseCode.normal.rawValue) {
        self.socket.disconnect(closeCode: closeCode)
        self.pingTimer?.invalidate()
    }
    
    func send(_ text: String) {
        guard self.isConnected else { return }
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
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected:
            self.websocketDidConnect(socket: client)
            break
        case .disconnected, .cancelled:
            DispatchQueue.main.sync {
                self.websocketDidDisconnect(socket: client, error: nil)
            }
            break
        case .text(let string):
            self.websocketDidReceiveMessage(socket: client, text: string)
            break
        case .binary(let data):
            self.websocketDidReceiveData(socket: client, data: data)
            break
        case .pong:
            LogService.shared.log("WC: <== pong")
            break
        case .ping:
            LogService.shared.log("WC: <== ping")
            break
        case .error(let error):
            self.websocketDidDisconnect(socket: client, error: error)
            break
        case .reconnectSuggested:
            LogService.shared.log("WC: <== reconnectSuggested") //TODO: Should we?
            break
        case .viabilityChanged:
            break
        }
    }
    
    private func websocketDidConnect(socket: WebSocketClient) {
        DispatchQueue.main.sync {
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: self.pingInterval,
                                                  repeats: true) { [weak self] _ in
                LogService.shared.log("WC: ==> ping")
                self?.socket.write(ping: Data())
            }
        }
        self.isConnected = true
        onConnect?()
    }
    
    private func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        pingTimer?.invalidate()
        self.isConnected = false
        onDisconnect?(error)
    }
    
    private func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        onTextReceive?(text)
    }
    
    private func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        // no-op
    }
}
