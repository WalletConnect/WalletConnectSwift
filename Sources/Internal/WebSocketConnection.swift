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

    // serial queue for receiving the calls.
    private let serialCallbackQueue: DispatchQueue

    private(set) var isOpen: Bool = false

    init(url: WCURL,
         onConnect: (() -> Void)?,
         onDisconnect: ((Error?) -> Void)?,
         onTextReceive: ((String) -> Void)?) {
        self.url = url
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
        self.onTextReceive = onTextReceive
        serialCallbackQueue = DispatchQueue(label: "org.walletconnect.swift.connection-\(url.bridgeURL)-\(url.topic)")
        socket = WebSocket(request: URLRequest(url: url.bridgeURL))
        socket.delegate = self
        socket.callbackQueue = serialCallbackQueue
    }

    deinit {
        pingTimer?.invalidate()
    }

    func open() {
        socket.connect()
    }

    func close() {
        socket.disconnect()
    }

    func send(_ text: String) {
        guard isOpen else { return }
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
            pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
                LogService.shared.log("WC: ==> ping")
                self?.socket.write(ping: Data())
            }
            LogService.shared.log("WC: ==> connected")
            isOpen = true
            onConnect?()
        case .disconnected:
            didDisconnect()
        case .error(let error):
            didDisconnect(with: error)
        case .text(let text):
            onTextReceive?(text)
        default:
            LogService.shared.log("WC: ==> unhandled event: \(event)")
            break
        }
    }

    private func didDisconnect(with error: Error? = nil) {
        LogService.shared.log("WC: ==> disconnected")
        if let error = error {
            LogService.shared.log("WC: ==> error: \(error)")
        }
        isOpen = false
        pingTimer?.invalidate()
        onDisconnect?(error)
    }
}
