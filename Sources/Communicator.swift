//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

class Communicator {

    // session are the approved connections between dApp and Wallet
    private let sessions: Sessions
    // triggered by Wallet or dApp to disconnect
    private let pendingDisconnectSessions: Sessions

    init() {
        sessions = Sessions(queue: DispatchQueue(label: "org.walletconnect.swift.server.sessions"))
        pendingDisconnectSessions = Sessions(queue: DispatchQueue(label: "org.walletconnect.swift.server.pending"))
    }

    func session(by url: WCURL) -> Session? {
        return sessions.find(url: url)
    }

    func addSession(_ session: Session) {
        sessions.add(session)
    }

    func removeSession(by url: WCURL) {
        sessions.remove(url: url)
    }

    func allSessions() -> [Session] {
        return sessions.all()
    }

    func pendingDisconnectSession(by url: WCURL) -> Session? {
        return pendingDisconnectSessions.find(url: url)
    }

    func addPendingDisconnectSession(_ session: Session) {
        pendingDisconnectSessions.add(session)
    }

    func removePendingDisconnectSession(by url: WCURL) {
        pendingDisconnectSessions.remove(url: url)
    }

    /// Thread-safe collection of Sessions
    private class Sessions {

        private var sessions: [WCURL: Session] = [:]
        private let queue: DispatchQueue

        init(queue: DispatchQueue) {
            self.queue = queue
        }

        func add(_ session: Session) {
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [unowned self] in
                self.sessions[session.url] = session
            }
        }

        func all() -> [Session] {
            var result: [Session] = []
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [unowned self] in
                result = Array(self.sessions.values)
            }
            return result
        }

        func find(url: WCURL) -> Session? {
            var result: Session?
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [unowned self] in
                result = self.sessions[url]
            }
            return result
        }

        func remove(url: WCURL) {
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [unowned self] in
                _ = self.sessions.removeValue(forKey: url)
            }
        }

    }

}
