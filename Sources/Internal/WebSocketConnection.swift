//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation
import Network

#if os(iOS)
import UIKit
#endif

enum WebSocketError: Error {
    case closedUnexpectedly
    case peerDisconnected
}


class WebSocketConnection {
    let url: WCURL
    private var isConnected: Bool = false
    private var task: URLSessionWebSocketTask?
    private lazy var session: URLSession = {
        let delegate = WebSocketConnectionDelegate(eventHandler: { [weak self] event in
            self?.handleEvent(event)
        })
        let configuration = URLSessionConfiguration.default
        configuration.shouldUseExtendedBackgroundIdleMode = true
        configuration.waitsForConnectivity = true

        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }()

#if os(iOS)
    private var bgTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var foregroundNotificationObserver: Any?
    private var backgroundNotificationObserver: Any?
#endif

    private let onConnect: (() -> Void)?
    private let onDisconnect: ((Error?) -> Void)?
    private let onTextReceive: ((String) -> Void)?

    // needed to keep connection alive
    private var pingTimer: Timer?

    // TODO: make injectable on server creation
    private let pingInterval: TimeInterval = 30
    private let timeoutInterval: TimeInterval = 20

    private var requestSerializer: RequestSerializer = JSONRPCSerializer()
    private var responseSerializer: ResponseSerializer = JSONRPCSerializer()

    var isOpen: Bool {
        return isConnected
    }

    init(url: WCURL,
         onConnect: (() -> Void)?,
         onDisconnect: ((Error?) -> Void)?,
         onTextReceive: ((String) -> Void)?
    ) {
        self.url = url
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
        self.onTextReceive = onTextReceive

    #if os(iOS)
        // On actual iOS devices, request some additional background execution time to the OS
        // each time that the app moves to background. This allows us to continue running for
        // around 30 secs in the background instead of having the socket killed instantly, which
        // solves the issue of connecting a wallet and a dApp both on the same device.
        // See https://github.com/WalletConnect/WalletConnectSwift/pull/81#issuecomment-1175931673

        if #available(iOS 14.0, *) {
            // We don't really need this on Apple Silicon Macs
            guard !ProcessInfo.processInfo.isiOSAppOnMac else { return }
        }

        self.backgroundNotificationObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didEnterBackgroundNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] _ in
            self?.requestBackgroundExecutionTime()
        }

        self.foregroundNotificationObserver = NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] _ in
            self?.endBackgroundExecutionTime()
        }
    #endif
    }

    deinit {
        session.invalidateAndCancel()
        pingTimer?.invalidate()

    #if os(iOS)
        if let observer = self.foregroundNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = self.backgroundNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    #endif
    }

    func open() {
        if task != nil {
            close()
        }

        let request = URLRequest(url: url.bridgeURL, timeoutInterval: timeoutInterval)
        task = session.webSocketTask(with: request)
        task?.resume()
        receive()
    }

    func close(closeCode: URLSessionWebSocketTask.CloseCode = .normalClosure) {
        pingTimer?.invalidate()
        task?.cancel(with: closeCode, reason: nil)
        task = nil
    }

    func send(_ text: String) {
        guard isConnected else { return }
        task?.send(.string(text)) { [weak self] error in
            if let error = error {
                self?.handleEvent(.connnectionError(error))
            } else {
                self?.handleEvent(.messageSent(text))
            }
        }
    }
}

private extension WebSocketConnection {

    enum WebSocketEvent {
        case connected
        case disconnected(URLSessionWebSocketTask.CloseCode)
        case messageReceived(String)
        case messageSent(String)
        case pingSent
        case pongReceived
        case connnectionError(Error)
    }

    func receive() {
        guard let task = task else { return }
        task.receive { [weak self] result in
            switch result {
            case .success(let message):
                if case let .string(text) = message {
                    self?.handleEvent(.messageReceived(text))
                }
                self?.receive()
            case .failure(let error):
                self?.handleEvent(.connnectionError(error))
            }
        }
    }

    func sendPing() {
        guard isConnected else { return }
        task?.sendPing(pongReceiveHandler: { [weak self] error in
            if let error = error {
                self?.handleEvent(.connnectionError(error))
            } else {
                self?.handleEvent(.pongReceived)
            }
        })
        handleEvent(.pingSent)
    }

    func handleEvent(_ event: WebSocketEvent) {
        switch event {
        case .connected:
            isConnected = true
            DispatchQueue.main.async {
                self.pingTimer = Timer.scheduledTimer(
                    withTimeInterval: self.pingInterval,
                    repeats: true
                ) { [weak self] _ in
                    self?.sendPing()
                }
            }
            LogService.shared.log("WC: connected")
            onConnect?()
        case .disconnected(let closeCode):
            guard isConnected else { break }
            isConnected = false
            pingTimer?.invalidate()

            var error: Error? = nil
            switch closeCode {
            case .normalClosure:
                LogService.shared.log("WC: disconnected (normal closure)")
            case .abnormalClosure, .goingAway:
                LogService.shared.log("WC: disconnected (peer disconnected)")
                error = WebSocketError.peerDisconnected
            default:
                LogService.shared.log("WC: disconnected (\(closeCode)")
                error = WebSocketError.closedUnexpectedly
            }
            onDisconnect?(error)
        case .messageReceived(let text):
            onTextReceive?(text)
        case .messageSent(let text):
            if let request = try? requestSerializer.deserialize(text, url: url).json().string {
                LogService.shared.log("WC: ==> [request] \(request)")
            } else if let response = try? responseSerializer.deserialize(text, url: url).json().string {
                LogService.shared.log("WC: ==> [response] \(response)")
            } else {
                LogService.shared.log("WC: ==> \(text)")
            }
        case .pingSent:
            LogService.shared.log("WC: ==> ping")
        case .pongReceived:
            LogService.shared.log("WC: <== pong")
        case .connnectionError(let error):
            LogService.shared.log("WC: Connection error: \(error.localizedDescription)")
            onDisconnect?(error)
        }
    }

    class WebSocketConnectionDelegate: NSObject, URLSessionWebSocketDelegate, URLSessionTaskDelegate {
        private let eventHandler: (WebSocketEvent) -> Void
        private var connectivityCheckTimer: Timer?

        init(eventHandler: @escaping (WebSocketEvent) -> Void) {
            self.eventHandler = eventHandler
        }

        func urlSession(
            _ session: URLSession,
            webSocketTask: URLSessionWebSocketTask,
            didOpenWithProtocol protocol: String?
        ) {
            self.connectivityCheckTimer?.invalidate()
            eventHandler(.connected)
        }

        func urlSession(
            _ session: URLSession,
            webSocketTask: URLSessionWebSocketTask,
            didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
            reason: Data?
        ) {
            eventHandler(.disconnected(closeCode))
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                eventHandler(.connnectionError(error))
            } else {
                // Possibly not really necessary since connection closure would likely have been reported
                // by the other delegate method, but just to be safe. We have checks in place to prevent
                // duplicated connection closing reporting anyway.
                eventHandler(.disconnected(.normalClosure))
            }
        }

        func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
            LogService.shared.log("WC: waiting for connectivity...")

            // Lets not wait forever, since the user might be waiting for the connection to show in the UI.
            // It's better to show an error -if it's a new session- or else let the retry logic do its job
            DispatchQueue.main.async {
                self.connectivityCheckTimer?.invalidate()
                self.connectivityCheckTimer = Timer.scheduledTimer(
                    withTimeInterval: task.originalRequest?.timeoutInterval ?? 30,
                    repeats: false
                ) { _ in
                    // Cancelling the task should trigger an invocation to `didCompleteWithError`
                    task.cancel()
                }
            }
        }
    }
}

#if os(iOS)
private extension WebSocketConnection {

    func requestBackgroundExecutionTime() {
        if bgTaskIdentifier != .invalid {
           endBackgroundExecutionTime()
        }

        bgTaskIdentifier = UIApplication.shared.beginBackgroundTask(
            withName: "WebSocketConnection-bgTime"
        ) { [weak self] in
            self?.endBackgroundExecutionTime()
        }
    }

    func endBackgroundExecutionTime() {
        guard bgTaskIdentifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bgTaskIdentifier)
        bgTaskIdentifier = .invalid
    }
}
#endif
