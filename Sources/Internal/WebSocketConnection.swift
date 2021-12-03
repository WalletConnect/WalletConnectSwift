//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation
import Starscream
import Network

class WebSocketConnection {
    let url: WCURL
    private let socket: WebSocket
    
    private var isConnected: Bool = false
    
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
        
        self.socket = WebSocket(request: URLRequest(url: url.bridgeURL), engine: WSEngine(transport: FoundationTransport(), certPinner: FoundationSecurity()))
        self.socket.callbackQueue = serialCallbackQueue
        self.socket.delegate = self
    }
    
    deinit {
        self.pingTimer?.invalidate()
    }
 
    func open() {
        self.socket.connect()
    }
    
    func close(closeCode: UInt16 = CloseCode.normal.rawValue) {
        self.socket.disconnect(closeCode: closeCode)
        self.pingTimer?.invalidate()
    }
    
    func send(_ text: String) {
        guard isConnected else { return }
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
            DispatchQueue.main.sync {
                self.pingTimer = Timer.scheduledTimer(withTimeInterval: self.pingInterval,
                                                      repeats: true) { [weak self] _ in
                    LogService.shared.log("WC: ==> ping")
                    self?.socket.write(ping: Data())
                }
            }
            LogService.shared.log("WC: <== connected")
            isConnected = true
            onConnect?()
        case .disconnected:
            didDisconnect(with: nil)
        case .error(let error):
            didDisconnect(with: error)
        case .cancelled:
            didDisconnect(with: nil)
        case .text(let string):
            onTextReceive?(string)
        case .ping:
            LogService.shared.log("WC: <== ping")
            LogService.shared.log("WC: ==> pong client.respondToPingWithPong: \(client.respondToPingWithPong == true)")
            break
        case .pong:
            LogService.shared.log("WC: <== pong")
        case .reconnectSuggested:
            LogService.shared.log("WC: <== reconnectSuggested") //TODO: Should we?
        case .binary, .viabilityChanged:
            break
        }
    }
    
    private func didDisconnect(with error: Error? = nil) {
        LogService.shared.log("WC: <== disconnected")
        if let error = error {
            LogService.shared.log("^------ with error: \(error)")
        }
        self.isConnected = false
        self.pingTimer?.invalidate()
        onDisconnect?(error)
    }
}
