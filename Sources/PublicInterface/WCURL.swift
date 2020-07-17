//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

public struct WCURL: Hashable, Codable {
    // topic is used for handshake only
    public var topic: String
    public var version: String
    public var bridgeURL: URL
    public var key: String

    public var absoluteString: String {
        let bridge = bridgeURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        return "wc:\(topic)@\(version)?bridge=\(bridge)&key=\(key)"
    }

    public init(topic: String,
                version: String = "1",
                bridgeURL: URL,
                key: String) {
        self.topic = topic
        self.version = version
        self.bridgeURL = bridgeURL
        self.key = key
    }

    public init?(_ str: String) {
        guard str.hasPrefix("wc:") else {
            return nil
        }
        let urlStr = !str.hasPrefix("wc://") ? str.replacingOccurrences(of: "wc:", with: "wc://") : str
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
