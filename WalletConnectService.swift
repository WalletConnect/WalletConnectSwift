//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation
import MultisigWalletDomainModel

public class WalletConnectService: WalletConnectDomainService {

    public weak var delegate: WalletConnectDomainServiceDelegate!

    var server: Server!

    enum ErrorCode: Int {
        case declinedSendTransactionRequest = -10_000
        case wrongSendTransactionRequest = -10_001
    }

    public init() {
        server = Server(delegate: self)
        server.register(handler: self)
    }

    public func connect(url: String) throws {
        guard let wcurl = WCURL(url) else { throw WCError.wrongURLFormat }
        do {
            try server.connect(to: wcurl)
        } catch {
            throw WCError.tryingToConnectExistingSessionURL
        }
    }

    public func reconnect(session: WCSession) throws {
        do {
            try server.reconnect(to: Session(wcSession: session))
        } catch {
            throw WCError.wrongSessionFormat
        }
    }

    public func disconnect(session: WCSession) throws {
        do {
            try server.disconnect(from: Session(wcSession: session))
        } catch {
            throw WCError.tryingToDisconnectInactiveSession
        }
    }

    public func openSessions() -> [WCSession] {
        return server.openSessions().map { $0.wcSession(status: .connected) }
    }

}

extension WalletConnectService: ServerDelegate {

    public func server(_ server: Server, didFailToConnect url: WCURL) {
        delegate.didFailToConnect(url: url.wcURL)
    }

    public func server(_ server: Server, shouldStart session: Session, completion: (Session.WalletInfo) -> Void) {
        delegate.shouldStart(session: session.wcSession(status: .connecting)) { wcWalletInfo in
            completion(Session.WalletInfo(wcWalletInfo: wcWalletInfo))
        }
    }

    public func server(_ server: Server, didConnect session: Session) {
        delegate.didConnect(session: session.wcSession(status: .connected))
    }

    public func server(_ server: Server, didDisconnect session: Session, error: Error?) {
        delegate.didDisconnect(session: session.wcSession(status: .disconnected))
    }

}

extension WalletConnectService: RequestHandler {

    public func canHandle(request: Request) -> Bool {
        return true
    }

    public func handle(request: Request) {
        if request.payload.method == "eth_sendTransaction" {
            do {
                print("Request payload: \(request.payload)")
                let data = try JSONEncoder().encode(request.payload.params)
                let requestWrapper = try JSONDecoder().decode([WCSendTransactionRequest].self, from: data)
                guard requestWrapper.count == 1 else {
                    let responsePayload = self.errorResponse(code: ErrorCode.wrongSendTransactionRequest.rawValue,
                                                             message: "Wrong send transaction request.",
                                                             requestId: request.payload.id!)
                    self.server.send(Response(payload: responsePayload, url: request.url))
                    return
                }
                delegate.handleSendTransactionRequest(requestWrapper[0]) { [weak self] result in
                    guard let self = self else { return }
                    var responsePayload: JSONRPC_2_0.Response
                    switch result {
                    case .success(let hash):
                        responsePayload = JSONRPC_2_0.Response(result: .value(.string(hash)),
                                                               id: request.payload.id!)
                    case .failure(let error):
                        let message = "Transaction was declined. Error: \(error.localizedDescription)"
                        responsePayload = self.errorResponse(code: ErrorCode.declinedSendTransactionRequest.rawValue,
                                                             message: message,
                                                             requestId: request.payload.id!)
                    }
                    self.server.send(Response(payload: responsePayload, url: request.url))
                }
            } catch {
                DomainRegistry.logger.error("Could not handle eth_sendTransaction from WalletConnect", error: error)
            }
        } else {
            // TODO: Discuss:
            // 1) should we allow to handle requests to a node at all?
            // 2) if yes, should Ethereum JSON RPC request handling be part of the lib itself?
            // 3) if no, send a method not supported response.
            delegate.handleEthereumNodeRequest(request.wcRequest) { [weak self] wcResponse in
                guard let self = self else { return }
                do {
                    let response = try Response(wcResponse: wcResponse)
                    self.server.send(response)
                } catch {
                    let message = "Could not create a Wallet Connect Response from: \(wcResponse.payload)"
                    DomainRegistry.logger.error(message, error: error)
                }
            }
        }
    }

    private func errorResponse(code: Int, message: String, requestId: JSONRPC_2_0.IDType) -> JSONRPC_2_0.Response {
        let code = try! JSONRPC_2_0.Response.Payload.ErrorPayload.Code(code)
        let errorPayload = JSONRPC_2_0.Response.Payload.ErrorPayload(code: code, message: message, data: nil)
        return JSONRPC_2_0.Response(result: .error(errorPayload), id: requestId)
    }

}

extension WCURL {

    init(wcURL: MultisigWalletDomainModel.WCURL) {
        self.init(topic: wcURL.topic, version: wcURL.version, bridgeURL: wcURL.bridgeURL, key: wcURL.key)
    }

    var wcURL: MultisigWalletDomainModel.WCURL {
        return MultisigWalletDomainModel.WCURL(topic: topic, version: version, bridgeURL: bridgeURL, key: key)
    }

}

extension Session.ClientMeta {

    init(wcClientMeta: WCClientMeta) {
        self.init(name: wcClientMeta.name,
                  description: wcClientMeta.description,
                  icons: wcClientMeta.icons,
                  url: wcClientMeta.url)
    }

    var wcClientMeta: WCClientMeta {
        return WCClientMeta(name: name, description: description, icons: icons, url: url)
    }

}

extension Session.DAppInfo {

    init(wcDAppInfo: WCDAppInfo) {
        self.init(peerId: wcDAppInfo.peerId, peerMeta: Session.ClientMeta(wcClientMeta: wcDAppInfo.peerMeta))
    }

    var wcDAppInfo: WCDAppInfo {
        return WCDAppInfo(peerId: peerId, peerMeta: peerMeta.wcClientMeta)
    }

}

extension Session.WalletInfo {

    init(wcWalletInfo: WCWalletInfo) {
        self.init(approved: wcWalletInfo.approved,
                  accounts: wcWalletInfo.accounts,
                  chainId: wcWalletInfo.chainId,
                  peerId: wcWalletInfo.peerId,
                  peerMeta: Session.ClientMeta(wcClientMeta: wcWalletInfo.peerMeta))
    }

    var wcWalletInfo: WCWalletInfo {
        return WCWalletInfo(approved: approved,
                            accounts: accounts,
                            chainId: chainId,
                            peerId: peerId,
                            peerMeta: peerMeta.wcClientMeta)
    }

}

extension Session {

    init(wcSession: WCSession) {
        self.init(url: WCURL(wcURL: wcSession.url),
                  dAppInfo: DAppInfo(wcDAppInfo: wcSession.dAppInfo),
                  walletInfo: Session.WalletInfo(wcWalletInfo: wcSession.walletInfo))
    }

    func wcSession(status: WCSessionStatus) -> WCSession {
        return WCSession(url: url.wcURL,
                         dAppInfo: dAppInfo.wcDAppInfo,
                         walletInfo: walletInfo!.wcWalletInfo,
                         status: status)
    }

}

extension Request {

    var wcRequest: WCMessage {
        return WCMessage(payload: try! payload.json().string, url: url.wcURL)
    }

}

extension Response {

    convenience init(wcResponse: WCMessage) throws {
        let payload = try JSONRPC_2_0.Response.create(from: JSONRPC_2_0.JSON(wcResponse.payload))
        let url = WCURL(wcURL: wcResponse.url)
        self.init(payload: payload, url: url)
    }

}
