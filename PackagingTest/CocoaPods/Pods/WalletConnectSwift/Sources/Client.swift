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
    ///   - message: String representin Data to sign.
    ///   - account: String representing Ethereum address.
    ///   - completion: Response with string representing signature, or error.
    /// - Throws: client error.
    public func personal_sign(url: WCURL,
                              message: String,
                              account: String,
                              completion: @escaping RequestResponse) throws {
        try sign(url: url, method: "personal_sign", param1: message, param2: account, completion: completion)
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
                         completion: @escaping RequestResponse) throws {
        try sign(url: url, method: "eth_sign", param1: account, param2: message, completion: completion)
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
                                  completion: @escaping RequestResponse) throws {
        try sign(url: url, method: "eth_signTypedData", param1: account, param2: message, completion: completion)
    }

    private func sign(url: WCURL,
                      method: String,
                      param1: String,
                      param2: String,
                      completion: @escaping RequestResponse) throws {
        let payload = JSONRPC_2_0.Request(method: method,
                                          params: .positional([.string(param1), .string(param2)]),
                                          id: .string(UUID().uuidString))
        let request = Request(payload: payload, url: url)
        try send(request, completion: completion)
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
                                    completion: @escaping RequestResponse) throws {
        try handleTransaction(url: url, method: "eth_sendTransaction", transaction: transaction, completion: completion)
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
                                    completion: @escaping RequestResponse) throws {
        try handleTransaction(url: url, method: "eth_signTransaction", transaction: transaction, completion: completion)
    }

    private func handleTransaction(url: WCURL,
                                   method: String,
                                   transaction: Transaction,
                                   completion: @escaping RequestResponse) throws {
        let requestParamsData = try JSONEncoder().encode([transaction])
        let requestParams = try JSONDecoder().decode(JSONRPC_2_0.Request.Params.self, from: requestParamsData)
        let payload = JSONRPC_2_0.Request(method: method,
                                          params: requestParams,
                                          id: .string(UUID().uuidString))
        let request = Request(payload: payload, url: url)
        try send(request, completion: completion)
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
    public func eth_sendRawTransaction(url: WCURL, data: String, completion: @escaping RequestResponse) throws {
        let payload = JSONRPC_2_0.Request(method: "eth_sendRawTransaction",
                                          params: .positional([.string(data)]),
                                          id: .string(UUID().uuidString))
        let request = Request(payload: payload, url: url)
        try send(request, completion: completion)
    }

    override func onConnect(to url: WCURL) {
        print("WC: client didConnect url: \(url.bridgeURL.absoluteString)")
        if let existingSession = communicator.session(by: url) {
            communicator.subscribe(on: existingSession.dAppInfo.peerId, url: existingSession.url)
            delegate.client(self, didConnect: existingSession)
        } else { // establishing new connection, handshake in process
            communicator.subscribe(on: dAppInfo.peerId, url: url)
            let requestID = nextRequestId()
            let createSessionRequest = try! CreateSessionRequest(url: url, dAppInfo: dAppInfo, id: requestID)!
            responses.add(requestID: requestID) { [unowned self] response in
                self.handleHandshakeResponse(response)
            }
            communicator.send(createSessionRequest, topic: url.topic)
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
        if let response = try? communicator.response(from: text, url: url) {
            log(response)
            if let completion = responses.find(requestID: response.payload.id) {
                completion(response)
                responses.remove(requestID: response.payload.id)
            }
        } else if let request = try? communicator.request(from: text, url: url) {
            log(request)
            expectUpdateSessionRequest(request)
        }
    }

    private func expectUpdateSessionRequest(_ request: Request) {
        if request.payload.method == "wc_sessionUpdate" {
            guard let approved = sessionApproval(from: request.payload.params) else {
                try! send(Response(payload: JSONRPC_2_0.Response.invalidJSON, url: request.url))
                return
            }
            guard let session = communicator.session(by: request.url) else { return }
            if !approved {
                do {
                    try disconnect(from: session)
                } catch { // session already disconnected
                    delegate.client(self, didDisconnect: session)
                }
            }
        } else {
            let payload = JSONRPC_2_0.Response.methodDoesNotExistError(id: request.payload.id)
            try! send(Response(payload: payload, url: request.url))
        }
    }

    private func sessionApproval(from requestParams: JSONRPC_2_0.Request.Params?) -> Bool? {
        guard let params = requestParams,
            case JSONRPC_2_0.Request.Params.positional(let arrayWrapper) = params, !arrayWrapper.isEmpty,
            case JSONRPC_2_0.ValueType.object(let sessionUpdateParams) = arrayWrapper[0],
            let requiredApproved = sessionUpdateParams["approved"],
            case JSONRPC_2_0.ValueType.bool(let approved) = requiredApproved else {
                return nil
        }
        return approved
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

    /// https://docs.walletconnect.org/json-rpc/ethereum#parameters-3
    public struct Transaction: Encodable {

        var from: String
        var to: String
        var data: String?
        var gasLimit: String?
        var gasPrice: String?
        var value: String?
        var nonce: String?

        public init(from: String,
                    to: String,
                    data: String?,
                    gasLimit: String?,
                    gasPrice: String?,
                    value: String?,
                    nonce: String?) {
            self.from = from
            self.to = to
            self.data = data
            self.gasLimit = gasLimit
            self.gasPrice = gasPrice
            self.value = value
            self.nonce = nonce
        }

    }

}
