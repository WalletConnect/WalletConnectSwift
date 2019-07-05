//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

public struct WCURL: Hashable {

    // topic is used for handshake only
    public var topic: String
    public var version: String
    public var bridgeURL: URL
    public var key: String

    public init?(_ str: String) {
        guard str.hasPrefix("wc:") else {
            return nil
        }
        let urlStr = str.replacingOccurrences(of: "wc:", with: "wc://")
        guard let url = URL(string: urlStr),
            let topic = url.user,
            let version = url.host,
            let components = NSURLComponents(url: url, resolvingAgainstBaseURL: false) else {
                return nil
        }
        var dict = [String: String]()
        for query in components.queryItems ?? [] {
            if let value = query.value {
                dict[query.name] = value
            }
        }
        guard let bridge = dict["bridge"],
            let bridgeUrl = URL(string: bridge),
            let key = dict["key"] else {
                return nil
        }
        self.topic = topic
        self.version = version
        self.bridgeURL = bridgeUrl
        self.key = key
    }

}

/// Each session is a communication channel between dApp and Wallet on dAppInfo.peerId topic
public struct Session {

    // TODO: handle protocol version
    public let url: WCURL
    public let dAppInfo: DAppInfo
    public var walletInfo: WalletInfo?

    public init(url: WCURL, dAppInfo: DAppInfo, walletInfo: WalletInfo?) {
        self.url = url
        self.dAppInfo = dAppInfo
        self.walletInfo = walletInfo
    }

    public struct DAppInfo: Codable {
        public var peerId: String
        public var peerMeta: ClientMeta
    }

    public struct ClientMeta: Codable {

        var name: String
        var description: String
        var icons: [URL]
        var url: URL

        public init(name: String, description: String, icons: [URL], url: URL) {
            self.name = name
            self.description = description
            self.icons = icons
            self.url = url
        }

    }

    public struct WalletInfo: Codable {

        public var approved: Bool
        public var accounts: [String]
        public var chainId: Int
        public var peerId: String
        public var peerMeta: ClientMeta

        public init(approved: Bool, accounts: [String], chainId: Int, peerId: String, peerMeta: ClientMeta) {
            self.approved = approved
            self.accounts = accounts
            self.chainId = chainId
            self.peerId = peerId
            self.peerMeta = peerMeta
        }

    }

    enum SessionCreationError: Error {
        case wrongRequestFormat
    }

    /// https://docs.walletconnect.org/tech-spec#session-request
    init?(wcSessionRequest request: Request) throws {
        let data = try JSONEncoder().encode(request.payload.params)
        let array = try JSONDecoder().decode([DAppInfo].self, from: data)
        guard array.count == 1 else { throw SessionCreationError.wrongRequestFormat }
        self.url = request.url
        self.dAppInfo = array[0]
    }

    func creationResponse(requestId: JSONRPC_2_0.IDType, walletInfo: Session.WalletInfo) -> Response {
        let infoValueData = try! JSONEncoder().encode(walletInfo)
        let infoValue = try! JSONDecoder().decode(JSONRPC_2_0.ValueType.self, from: infoValueData)
        let result = JSONRPC_2_0.Response.Payload.value(infoValue)
        let JSONRPCResponse = JSONRPC_2_0.Response(result: result, id: requestId)
        return Response(payload: JSONRPCResponse, url: self.url)
    }

}
