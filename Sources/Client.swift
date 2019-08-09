//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

/*
 Client:

 connect
 reconnect
 disconnect
 updateSession

 WC API:
 personal_sign
 eth_sign
 eth_signTypedData
 eth_sendTransaction
 eth_signTransaction
 eth_sendRawTransaction

 general:
 send(_ request: Request)

 */

public protocol ClientDelegate: class {

    func client(_ client: Client, didFailToConnect url: WCURL)
    func client(_ client: Client, didConnect session: Session)
    func client(_ client: Client, didDisconnect session: Session, error: Error? )

}

public class Client {

    private(set) weak var delegate: ClientDelegate!
    private let dAppInfo: Session.DAppInfo
    private let communicator: Communicator

    private var pendingRequestsCompletion = [JSONRPC_2_0.IDType: ((Response) -> Void)]()

    enum ClientError: Error {
        case tryingToConnectExistingSessionURL
    }

    public init(delegate: ClientDelegate, dAppInfo: Session.DAppInfo) {
        self.delegate = delegate
        self.dAppInfo = dAppInfo
        communicator = Communicator()
    }

    public func connect(url: WCURL) throws {
        guard communicator.session(by: url) == nil else {
            throw ClientError.tryingToConnectExistingSessionURL
        }
        communicator.listen(on: url,
                            onConnect: onConnect(to:),
                            onDisconnect: onDisconnect(from:error:),
                            onTextReceive: onTextReceive(_:from:))
    }

    private func onConnect(to url: WCURL) {
        print("WC: client didConnect url: \(url.bridgeURL.absoluteString)")
        if let session = communicator.session(by: url) { // reconnecting existing session
            communicator.subscribe(on: session.dAppInfo.peerId, url: session.url)
            delegate.client(self, didConnect: session)
        } else { // establishing new connection, handshake in process
            communicator.subscribe(on: dAppInfo.peerId, url: url)
            let requestID = nextRequestId()
            let createRequest = try! CreateSessionRequest(url: url, dAppInfo: dAppInfo, id: requestID)!
            pendingRequestsCompletion[requestID] = { [unowned self] response in
                self.handleHandshakeResponse(response)
            }
            communicator.send(createRequest, topic: url.topic)
        }
    }

    private func onDisconnect(from url: WCURL, error: Error?) {}

    private func onTextReceive(_ text: String, from url: WCURL) {
        // TODO: handle all situations
        if let response = try? communicator.response(from: text, url: url) {
            log(response)
            if let completion = pendingRequestsCompletion[response.payload.id] {
                completion(response)
                pendingRequestsCompletion.removeValue(forKey: response.payload.id)
            }
        }
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

    private func log(_ response: Response) {
        guard let text = try? response.payload.json().string else { return }
        print("WC: <== \(text)")
    }

    private func nextRequestId() -> JSONRPC_2_0.IDType {
        return JSONRPC_2_0.IDType.int(UUID().hashValue)
    }

}
