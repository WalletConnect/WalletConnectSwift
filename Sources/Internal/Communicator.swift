//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

class Communicator {
    // sessions are the approved connections between dApp and Wallet
    private let sessions: Sessions
    // triggered by Wallet or dApp to disconnect
    private let pendingDisconnectSessions: Sessions

    private let transport: Transport
    private let responseSerializer: ResponseSerializer
    private let requestSerializer: RequestSerializer

    init() {
        sessions = Sessions(queue: DispatchQueue(label: "org.walletconnect.swift.server.sessions"))
        pendingDisconnectSessions = Sessions(queue: DispatchQueue(label: "org.walletconnect.swift.server.pending"))
        transport = Bridge()
        let serializer = JSONRPCSerializer()
        responseSerializer = serializer
        requestSerializer = serializer
    }

    // MARK: - Sessions

    func session(by url: WCURL) -> Session? {
        return sessions.find(url: url)
    }

    func addOrUpdateSession(_ session: Session) {
        sessions.addOrUpdate(session)
    }

    func removeSession(by url: WCURL) {
        sessions.remove(url: url)
    }

    func openSessions() -> [Session] {
        return sessions.all().filter { transport.isConnected(by: $0.url) }
    }

    func isConnected(by url: WCURL) -> Bool {
        return transport.isConnected(by: url)
    }

    func disconnect(from url: WCURL) {
        transport.disconnect(from: url)
    }

    func pendingDisconnectSession(by url: WCURL) -> Session? {
        return pendingDisconnectSessions.find(url: url)
    }

    func addOrUpdatePendingDisconnectSession(_ session: Session) {
        pendingDisconnectSessions.addOrUpdate(session)
    }

    func removePendingDisconnectSession(by url: WCURL) {
        pendingDisconnectSessions.remove(url: url)
    }

    // MARK: - Transport

    func listen(on url: WCURL,
                onConnect: @escaping ((WCURL) -> Void),
                onDisconnect: @escaping ((WCURL, Error?) -> Void),
                onTextReceive: @escaping (String, WCURL) -> Void) {
        transport.listen(on: url,
                         onConnect: onConnect,
                         onDisconnect: onDisconnect,
                         onTextReceive: onTextReceive)
    }

    func subscribe(on topic: String, url: WCURL) {
        let message = PubSubMessage(topic: topic, type: .sub, payload: "")
        transport.send(to: url, text: try! message.json())
    }

    func send(_ response: Response, topic: String) {
        let text = try! responseSerializer.serialize(response, topic: topic)
        transport.send(to: response.url, text: text)
    }

    func send(_ request: Request, topic: String) {
        let text = try! requestSerializer.serialize(request, topic: topic)
        transport.send(to: request.url, text: text)
    }

    // MARK: - Serialization

    func request(from text: String, url: WCURL) throws -> Request {
        return try requestSerializer.deserialize(text, url: url)
    }

    func response(from text: String, url: WCURL) throws -> Response {
        return try responseSerializer.deserialize(text, url: url)
    }

    /// Thread-safe collection of Sessions
    private class Sessions {
        private var sessions: [WCURL: Session] = [:]
        private let queue: DispatchQueue

        init(queue: DispatchQueue) {
            self.queue = queue
        }

        func addOrUpdate(_ session: Session) {
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [weak self] in
                self?.sessions[session.url] = session
            }
        }

        func all() -> [Session] {
            var result: [Session] = []
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [weak self] in
                guard let self = self else { return }
                result = Array(self.sessions.values)
            }
            return result
        }

        func find(url: WCURL) -> Session? {
            var result: Session?
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [weak self] in
                guard let self = self else { return }
                result = self.sessions[url]
            }
            return result
        }

        func remove(url: WCURL) {
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [weak self] in
                _ = self?.sessions.removeValue(forKey: url)
            }
        }
    }
}
