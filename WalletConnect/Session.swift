//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

public struct WCURL: Hashable, CustomStringConvertible {

    public var topic: String
    public var version: String
    public var bridgeURL: URL
    public var key: String

    public var description: String {
        return "topic: \(topic); version: \(version); bridge: \(bridgeURL.absoluteString); key: \(key)"
    }

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

/// Session is a connection between dApp and Wallet
public struct Session {

    // TODO: handle protocol version
    public var url: WCURL
    // dApp id that is used as topic to send responses
    public var peerId: String
    public var clientMeta: ClientMeta

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
        struct ParamsArrayWrapper: Codable {
            var peerId: String
            var peerMeta: ClientMeta
        }
        let data = try JSONEncoder().encode(request.payload.params)
        let array = try JSONDecoder().decode([ParamsArrayWrapper].self, from: data)
        guard array.count == 1 else { throw SessionCreationError.wrongRequestFormat }
        let wrapper = array[0]
        self.url = request.url
        self.peerId = wrapper.peerId
        self.clientMeta = wrapper.peerMeta
    }

    func creationResponse(requestId: JSONRPC_2_0.IDType, info: Session.WalletInfo) -> Response {
        let infoValueData = try! JSONEncoder().encode(info)
        let infoValue = try! JSONDecoder().decode(JSONRPC_2_0.ValueType.self, from: infoValueData)
        let result = JSONRPC_2_0.Response.Payload.value(infoValue)
        let JSONRPCResponse = JSONRPC_2_0.Response(result: result, id: requestId)
        return Response(payload: JSONRPCResponse, url: self.url)
    }

}
