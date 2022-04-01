//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

/// Each session is a communication channel between dApp and Wallet on dAppInfo.peerId topic
public struct Session: Codable {
    // TODO: handle protocol version
    public let url: WCURL
    public let dAppInfo: DAppInfo
    public var walletInfo: WalletInfo?

    public init(url: WCURL, dAppInfo: DAppInfo, walletInfo: WalletInfo?) {
        self.url = url
        self.dAppInfo = dAppInfo
        self.walletInfo = walletInfo
    }

    public struct DAppInfo: Codable, Equatable {
        public let peerId: String
        public let peerMeta: ClientMeta
        public let chainId: Int?
        public let approved: Bool?

        public init(peerId: String, peerMeta: ClientMeta, chainId: Int? = nil, approved: Bool? = nil) {
            self.peerId = peerId
            self.peerMeta = peerMeta
            self.chainId = chainId
            self.approved = approved
        }

        func with(approved: Bool) -> DAppInfo {
            return DAppInfo(peerId: self.peerId,
                            peerMeta: self.peerMeta,
                            chainId: self.chainId,
                            approved: approved)
        }
    }

	public struct ClientMeta: Codable, Equatable {
		public let name: String
		public let description: String?
		public let iconsStr: [String]?
		public var icons: [URL] {
			var urls: [URL] = []
			for iconStr in iconsStr ?? [] {
				if let u = URL(string: iconStr) {
					urls.append(u)
				}
			}
			return urls
		}
		public let url: URL?
		public let scheme: String?

		enum CodingKeys: String, CodingKey {
			case name = "name"
			case description = "description"
			case iconsStr = "icons"
			case url = "url"
			case scheme = "scheme"
		}

		public init(name: String, description: String?, icons: [URL], url: URL, scheme: String? = nil) {
			self.name = name
			self.description = description
			self.iconsStr = icons.map({ url in
				url.absoluteString
			})
			self.url = url
			self.scheme = scheme
		}
	}

    public struct WalletInfo: Codable, Equatable {
        public let approved: Bool
        public let accounts: [String]
        public let chainId: Int
        public let peerId: String
        public let peerMeta: ClientMeta

        public init(approved: Bool, accounts: [String], chainId: Int, peerId: String, peerMeta: ClientMeta) {
            self.approved = approved
            self.accounts = accounts
            self.chainId = chainId
            self.peerId = peerId
            self.peerMeta = peerMeta
        }

        public func with(approved: Bool) -> WalletInfo {
            return WalletInfo(approved: approved,
                              accounts: self.accounts,
                              chainId: self.chainId,
                              peerId: self.peerId,
                              peerMeta: self.peerMeta)
        }
    }
}
