//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation
import MultisigWalletDomainModel

// TODO: make this service very thin and move domain specific logic to special new domain object.
public class WalletConnectService: WalletConnectDomainService {

    private weak var delegate: WalletConnectDomainServiceDelegate!

    var server: Server!

    enum ErrorCode: Int {
        case declinedSendTransactionRequest = -10_000
        case wrongSendTransactionRequest = -10_001
    }

    public init() {
        server = Server(delegate: self)
        server.register(handler: self)
    }

    public func updateDelegate(_ delegate: WalletConnectDomainServiceDelegate) {
        self.delegate = delegate
    }

    public func connect(url: String) throws {
        guard let wcurl = WCURL(url) else { throw WCError.wrongURLFormat }
        do {
            // Stub data will be updated with real data once the connection is established.
            let stubURL = URL(string: "https://safe.gnosis.io")!
            let stubMeta = WCClientMeta(name: "", description: "", icons: [], url: stubURL)
            let newSession = WCSession(url: wcurl.wcURL,
                                       dAppInfo: WCDAppInfo(peerId: "", peerMeta: stubMeta),
                                       walletInfo: nil,
                                       status: .connecting)
            DomainRegistry.walletConnectSessionRepository.save(newSession)
            try server.connect(to: wcurl)
        } catch {
            throw WCError.tryingToConnectExistingSessionURL
        }
    }

    public func reconnect(session: WCSession) throws {
        guard session.walletInfo != nil else {
            // Trying to reconnect a session without handshake process finished.
            // It could happed when the app restarts in the middle of the process.
            DomainRegistry.walletConnectSessionRepository.remove(session)
            return
        }
        do {
            try server.reconnect(to: Session(wcSession: session))
        } catch {
            throw WCError.wrongSessionFormat
        }
    }

    public func disconnect(session: WCSession) throws {
        guard session.walletInfo != nil else {
            // Trying to disconnect connecting session.
            DomainRegistry.walletConnectSessionRepository.remove(session)
            return
        }
        do {
            try server.disconnect(from: Session(wcSession: session))
        } catch {
            throw WCError.tryingToDisconnectInactiveSession
        }
    }

    public func sessions() -> [WCSession] {
        return DomainRegistry.walletConnectSessionRepository.all().sorted { $0.created > $1.created }
    }

}

extension WalletConnectService: ServerDelegate {

    public func server(_ server: Server, didFailToConnect url: WCURL) {
        delegate.didFailToConnect(url: url.wcURL)
    }

    public func server(_ server: Server, shouldStart session: Session, completion: (Session.WalletInfo) -> Void) {
        guard let existingSession = findExistingWCSession(for: session) else { return }
        delegate.shouldStart(session: session.wcSession(status: .connecting,
                                                        created: existingSession.created)) { wcWalletInfo in
            completion(Session.WalletInfo(wcWalletInfo: wcWalletInfo))
        }
    }

    public func server(_ server: Server, didConnect session: Session) {
        guard let existingSession = findExistingWCSession(for: session) else { return }
        let updatedSession = session.wcSession(status: .connected, created: existingSession.created)
        DomainRegistry.walletConnectSessionRepository.save(updatedSession)
        delegate.didConnect(session: updatedSession)
    }

    public func server(_ server: Server, didDisconnect session: Session, error: Error?) {
        guard let existingSession = findExistingWCSession(for: session) else { return }
        DomainRegistry.walletConnectSessionRepository.remove(existingSession)
        delegate.didDisconnect(session: session.wcSession(status: .disconnected, created: existingSession.created))
    }

    private func findExistingWCSession(for session: Session) -> WCSession? {
        return DomainRegistry.walletConnectSessionRepository.find(id: WCSessionID(session.url.topic))
    }

}

extension WalletConnectService: RequestHandler {

    var unsupportedWalletConnectRequests: [String] {
        return ["personal_sign", "eth_sign", "eth_signTypedData", "eth_signTransaction", "eth_sendRawTransaction"]
    }

    public func canHandle(request: Request) -> Bool {
        return !unsupportedWalletConnectRequests.contains(request.payload.method)
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
                                                             requestId: request.payload.id ?? .null)
                    self.server.send(Response(payload: responsePayload, url: request.url))
                    return
                }
                var wcRequest = requestWrapper[0]
                wcRequest.url = request.url.wcURL
                delegate.handleSendTransactionRequest(wcRequest) { [weak self] result in
                    guard let self = self else { return }
                    var responsePayload: JSONRPC_2_0.Response
                    switch result {
                    case .success(let hash):
                        responsePayload = JSONRPC_2_0.Response(result: .value(.string(hash)),
                                                               id: request.payload.id ?? .null)
                    case .failure(let error):
                        let message = "Transaction was declined. Error: \(error.localizedDescription)"
                        responsePayload = self.errorResponse(code: ErrorCode.declinedSendTransactionRequest.rawValue,
                                                             message: message,
                                                             requestId: request.payload.id ?? .null)
                    }
                    self.server.send(Response(payload: responsePayload, url: request.url))
                }
            } catch {
                DomainRegistry.logger.error("WC: Could not handle eth_sendTransaction from WalletConnect", error: error)
            }
        } else {
            // TODO: Discuss: should Ethereum JSON RPC request handling be part of the lib itself?
            delegate.handleEthereumNodeRequest(request.wcRequest) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let wcResponse):
                    do {
                        let response = try Response(wcResponse: wcResponse)
                        self.server.send(response)
                    } catch {
                        // TODO: discuss if we should send a failure response.
                        let message = "WC: Could not create a WalletConnect Response from: \(wcResponse.payload)"
                        DomainRegistry.logger.error(message, error: error)
                    }
                case .failure(let error):
                    let message = "WC: Could not send a WalletConnect request: \(request.payload)"
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
                  walletInfo: wcSession.walletInfo == nil ?
                    nil :
                    Session.WalletInfo(wcWalletInfo: wcSession.walletInfo!))
    }

    func wcSession(status: WCSessionStatus, created: Date) -> WCSession {
        return WCSession(url: url.wcURL,
                         dAppInfo: dAppInfo.wcDAppInfo,
                         walletInfo: walletInfo?.wcWalletInfo,
                         status: status,
                         created: created)
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
