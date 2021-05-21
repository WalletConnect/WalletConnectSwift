//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

public protocol ClientDelegate: class {
    func client(_ client: Client, didFailToConnect url: WCURL)
    func client(_ client: Client, didConnect session: Session)
    func client(_ client: Client, didDisconnect session: Session)
}

public class Client: WalletConnect {
    public typealias RequestResponse = (Response) -> Void

    private(set) weak var delegate: ClientDelegate?
    private let dAppInfo: Session.DAppInfo
    private var responses: Responses

    public enum ClientError: Error {
        case missingWalletInfoInSession
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
    public func send(_ request: Request, onResponse: RequestResponse?) throws {
        guard let session = communicator.session(by: request.url) else {
            throw ClientError.sessionNotFound
        }
        guard let walletInfo = session.walletInfo else {
            throw ClientError.missingWalletInfoInSession
        }
        if let onResponse = onResponse, let requestID = request.internalID, requestID != .null {
            responses.add(requestID: requestID, response: onResponse)
        }
        communicator.send(request, topic: walletInfo.peerId)
    }

    /// Send response to wallet.
    ///
    /// - Parameter response: Response object.
    /// - Throws: Client error.
    public func send(_ response: Response) throws {
        guard let session = communicator.session(by: response.url) else {
            throw ClientError.sessionNotFound
        }
        guard let walletInfo = session.walletInfo else {
            throw ClientError.missingWalletInfoInSession
        }
        communicator.send(response, topic: walletInfo.peerId)
    }

    /// Request to sign a message.
    ///
    /// https://docs.walletconnect.org/json-rpc/ethereum#personal_sign
    ///
    /// - Parameters:
    ///   - url: WalletConnect url object.
    ///   - message: String representing human readable message to sign.
    ///   - account: String representing Ethereum address.
    ///   - completion: Response with string representing signature, or error.
    /// - Throws: client error.
    public func personal_sign(url: WCURL,
                              message: String,
                              account: String,
                              completion: () -> Void,
                              onResponse: @escaping RequestResponse) throws {
        let messageHex = message.data(using: .utf8)!.map { String(format: "%02x", $0) }.joined()
        try sign(url: url, method: "personal_sign", param1: messageHex, param2: account, completion: onResponse)
        completion()
    }

    /// Request to sign a message.
    ///
    /// https://docs.walletconnect.org/json-rpc/ethereum#eth_sign
    ///
    /// - Parameters:
    ///   - url: WalletConnect url object.
    ///   - account: String representing Ethereum address.
    ///   - message: String representin Data to sign.
    ///   - completion: Response with string representing signature, or error.
    /// - Throws: client error.
    public func eth_sign(url: WCURL,
                         account: String,
                         message: String,
                         completion: () -> Void,
                         onResponse: @escaping RequestResponse) throws {
        try sign(url: url, method: "eth_sign", param1: account, param2: message, completion: onResponse)
        completion()
    }

    /// Request to sign typed daya.
    ///
    /// https://docs.walletconnect.org/json-rpc/ethereum#eth_signtypeddata
    ///
    /// - Parameters:
    ///   - url: WalletConnect url object.
    ///   - account: String representing Ethereum address.
    ///   - message: String representin Data to sign.
    ///   - completion: Response with string representing signature, or error.
    /// - Throws: client error.
    public func eth_signTypedData(url: WCURL,
                                  account: String,
                                  message: String,
                                  completion: () -> Void,
                                  onResponse: @escaping RequestResponse) throws {
        try sign(url: url, method: "eth_signTypedData", param1: account, param2: message, completion: onResponse)
        completion()
    }

    private func sign(url: WCURL,
                      method: String,
                      param1: String,
                      param2: String,
                      completion: @escaping RequestResponse) throws {
        let request = try Request(url: url, method: method, params: [param1, param2])
        try send(request, onResponse: completion)
    }

    /// Request to send a transaction.
    ///
    /// https://docs.walletconnect.org/json-rpc/ethereum#eth_sendtransaction
    ///
    /// - Parameters:
    ///   - url: WalletConnect url object.
    ///   - transaction: Transaction object.
    ///   - completion: Response with string representing transaction hash, or error.
    /// - Throws: client error.
    public func eth_sendTransaction(url: WCURL,
                                    transaction: Transaction,
                                    completion: () -> Void,
                                    onResponse: @escaping RequestResponse) throws {
        try handleTransaction(url: url, method: "eth_sendTransaction", transaction: transaction, onResponse: onResponse)
        
        completion()
    }

    /// Request to sign a transaction.
    ///
    /// https://docs.walletconnect.org/json-rpc/ethereum#eth_signtransaction
    ///
    /// - Parameters:
    ///   - url: WalletConnect url object.
    ///   - transaction: Transaction object.
    ///   - completion: Response with string representing transaction signature, or error.
    /// - Throws: client error.
    public func eth_signTransaction(url: WCURL,
                                    transaction: Transaction,
                                    completion: () -> Void,
                                    onResponse: @escaping RequestResponse) throws {
        try handleTransaction(url: url, method: "eth_signTransaction", transaction: transaction, onResponse: onResponse)
        completion()
    }

    private func handleTransaction(url: WCURL,
                                   method: String,
                                   transaction: Transaction,
                                   onResponse: @escaping RequestResponse) throws {
        let request = try Request(url: url, method: method, params: [transaction])
        try send(request, onResponse: onResponse)
    }

    /// Request to send a raw transaction. Creates new message call transaction or
    /// a contract creation for signed transactions.
    ///
    /// https://docs.walletconnect.org/json-rpc/ethereum#eth_sendrawtransaction
    ///
    /// - Parameters:
    ///   - url: WalletConnect url object.
    ///   - data: Data as String.
    ///   - completion: Response with the transaction hash, or the zero hash if the transaction is not
    ///                 yet available, or error.
    /// - Throws: client error.
    public func eth_sendRawTransaction(url: WCURL, data: String, completion: () -> Void, onResponse: @escaping RequestResponse) throws {
        let request = try Request(url: url, method: "eth_sendRawTransaction", params: [data])
        try send(request, onResponse: onResponse)
        
        completion()
    }

    override func onConnect(to url: WCURL) {
        LogService.shared.log("WC: client didConnect url: \(url.bridgeURL.absoluteString)")
        if let existingSession = communicator.session(by: url) {
            communicator.subscribe(on: existingSession.dAppInfo.peerId, url: existingSession.url)
            delegate?.client(self, didConnect: existingSession)
        } else { // establishing new connection, handshake in process
            communicator.subscribe(on: dAppInfo.peerId, url: url)
            let request = try! Request(url: url, method: "wc_sessionRequest", params: [dAppInfo], id: Request.payloadId())
            let requestID = request.internalID!
            responses.add(requestID: requestID) { [unowned self] response in
                self.handleHandshakeResponse(response)
            }
            communicator.send(request, topic: url.topic)
        }
    }


    private func handleHandshakeResponse(_ response: Response) {
        do {
            let walletInfo = try response.result(as: Session.WalletInfo.self)
            let session = Session(url: response.url, dAppInfo: dAppInfo, walletInfo: walletInfo)

            guard walletInfo.approved else {
                // TODO: handle Error
                delegate?.client(self, didFailToConnect: response.url)
                return
            }

            communicator.addSession(session)
            delegate?.client(self, didConnect: session)
        } catch {
            // TODO: handle error
            delegate?.client(self, didFailToConnect: response.url)
        }
    }

    override func onTextReceive(_ text: String, from url: WCURL) {
        if let response = try? communicator.response(from: text, url: url) {
            log(response)
            if let completion = responses.find(requestID: response.internalID) {
                completion(response)
                responses.remove(requestID: response.internalID)
            }
        } else if let request = try? communicator.request(from: text, url: url) {
            log(request)
            expectUpdateSessionRequest(request)
        }
    }

    private func expectUpdateSessionRequest(_ request: Request) {
        if request.method == "wc_sessionUpdate" {
            guard let approval = sessionApproval(from: request) else {
                // TODO: error handling
                try! send(Response(request: request, error: .invalidJSON))
                return
            }
            guard let session = communicator.session(by: request.url), !approval else { return }
            do {
                try disconnect(from: session)
            } catch { // session already disconnected
                delegate?.client(self, didDisconnect: session)
            }
        } else {
            // TODO: error handling
            let response = try! Response(request: request, error: .methodNotFound)
            try! send(response)
        }
    }

    private func sessionApproval(from request: Request) -> Bool? {
        do {
            let info = try request.parameter(of: SessionInfo.self, at: 0)
            return info.approved
        } catch {
            LogService.shared.log("WC: incoming approval cannot be parsed: \(error)")
            return nil
        }
    }

    override func sendDisconnectSessionRequest(for session: Session) throws {
        let dappInfo = session.dAppInfo.with(approved: false)
        let request = try Request(url: session.url, method: "wc_sessionUpdate", params: [dappInfo], id: nil)
        try send(request, onResponse: nil)
    }

    override func failedToConnect(_ url: WCURL) {
        delegate?.client(self, didFailToConnect: url)
    }

    override func didDisconnect(_ session: Session) {
        delegate?.client(self, didDisconnect: session)
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

    /// https://docs.walletconnect.org/json-rpc/ethereum#parameters-3
    public struct Transaction: Encodable {
        var from: String
        var to: String?
        var data: String
        var gas: String?
        var gasPrice: String?
        var value: String?
        var nonce: String?

        public init(from: String,
                    to: String?,
                    data: String,
                    gas: String?,
                    gasPrice: String?,
                    value: String?,
                    nonce: String?) {
            self.from = from
            self.to = to
            self.data = data
            self.gas = gas
            self.gasPrice = gasPrice
            self.value = value
            self.nonce = nonce
        }
    }
}
