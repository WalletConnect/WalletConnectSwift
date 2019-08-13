//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

/*
 WC API:
 personal_sign
 eth_sign
 eth_signTypedData
 eth_sendTransaction
 eth_signTransaction
 eth_sendRawTransaction
 */

public protocol ClientDelegate: class {

    func client(_ client: Client, didFailToConnect url: WCURL)
    func client(_ client: Client, didConnect session: Session)
    func client(_ client: Client, didDisconnect session: Session)

}

public class Client: WalletConnect {

    public typealias RequestResponse = (Response) -> Void

    private(set) weak var delegate: ClientDelegate!
    private let dAppInfo: Session.DAppInfo
    private var responses: Responses

    enum ClientError: Error {
        case missingWalletInfoInSession
        case missingRequestID
        case sessionNotFound
    }

    public init(delegate: ClientDelegate, dAppInfo: Session.DAppInfo) {
        self.delegate = delegate
        self.dAppInfo = dAppInfo
        responses = Responses(queue: DispatchQueue(label: "org.walletconnect.swift.client.pending"))
        super.init()
    }

    /// Send request to wallet.
    ///
    /// - Parameters:
    ///   - request: Request object.
    ///   - completion: RequestResponse completion.
    /// - Throws: Client error.
    public func send(_ request: Request, completion: RequestResponse?) throws {
        guard let session = communicator.session(by: request.url) else {
            throw ClientError.sessionNotFound
        }
        guard let walletInfo = session.walletInfo else {
            throw ClientError.missingWalletInfoInSession
        }
        guard let requestID = request.payload.id else {
            throw ClientError.missingRequestID
        }
        if let completion = completion {
            responses.add(requestID: requestID, response: completion)
        }
        communicator.send(request, topic: walletInfo.peerId)
    }

    override func onConnect(to url: WCURL) {
        print("WC: client didConnect url: \(url.bridgeURL.absoluteString)")
        if let session = communicator.session(by: url) { // reconnecting existing session
            communicator.subscribe(on: session.dAppInfo.peerId, url: session.url)
            delegate.client(self, didConnect: session)
        } else { // establishing new connection, handshake in process
            communicator.subscribe(on: dAppInfo.peerId, url: url)
            let requestID = nextRequestId()
            let createRequest = try! CreateSessionRequest(url: url, dAppInfo: dAppInfo, id: requestID)!
            responses.add(requestID: requestID) { [unowned self] response in
                self.handleHandshakeResponse(response)
            }
            communicator.send(createRequest, topic: url.topic)
        }
    }

    private func nextRequestId() -> JSONRPC_2_0.IDType {
        return JSONRPC_2_0.IDType.int(UUID().hashValue)
    }

    private func handleHandshakeResponse(_ response: Response) {
        guard let session = try? Session(wcSessionResponse: response, dAppInfo: dAppInfo),
            session.walletInfo!.approved else {
                delegate.client(self, didFailToConnect: response.url)
                return
        }
        communicator.addSession(session)
        delegate.client(self, didConnect: session)
    }

    override func onTextReceive(_ text: String, from url: WCURL) {
        // TODO: handle all situations
        if let response = try? communicator.response(from: text, url: url) {
            log(response)
            if let completion = responses.find(requestID: response.payload.id) {
                completion(response)
                responses.remove(requestID: response.payload.id)
            }
        }
    }

    private func log(_ response: Response) {
        guard let text = try? response.payload.json().string else { return }
        print("WC: <== \(text)")
    }

    override func sendDisconnectSessionRequest(for session: Session) throws {
        let request = try! UpdateSessionRequest(url: session.url, dAppInfo: session.dAppInfo.with(approved: false))!
        try send(request, completion: nil)
    }

    override func failedToConnect(_ url: WCURL) {
        delegate.client(self, didFailToConnect: url)
    }

    override func didDisconnect(_ session: Session) {
        delegate.client(self, didDisconnect: session)
    }

    /// Thread-safe collection of client reponses
    private class Responses {

        private var responses = [JSONRPC_2_0.IDType: RequestResponse]()
        private let queue: DispatchQueue

        init(queue: DispatchQueue) {
            self.queue = queue
        }

        func add(requestID: JSONRPC_2_0.IDType, response: @escaping RequestResponse) {
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [unowned self] in
                self.responses[requestID] = response
            }
        }

        func find(requestID: JSONRPC_2_0.IDType) -> RequestResponse? {
            var result: RequestResponse?
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [unowned self] in
                result = self.responses[requestID]
            }
            return result
        }

        func remove(requestID: JSONRPC_2_0.IDType) {
            dispatchPrecondition(condition: .notOnQueue(queue))
            queue.sync { [unowned self] in
                _ = self.responses.removeValue(forKey: requestID)
            }
        }

    }

}
