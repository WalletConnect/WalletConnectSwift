//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

enum DataConversionError: Error {
    case stringToDataFailed
    case dataToStringFailed
}

class PubSubAdapter {

    struct Message: Codable {

        /// WalletConnect topic
        var topic: String
        /// pub/sub message type
        var type: MessageType
        /// encoded JSONRPC data.
        var payload: String

        enum MessageType: String, Codable {
            case pub
            case sub
        }

    }

    func message(from string: String) throws -> Message {
        guard let data = string.data(using: .utf8) else {
            throw DataConversionError.stringToDataFailed
        }
        return try JSONDecoder().decode(Message.self, from: data)
    }

    func string(from message: Message) throws -> String {
        let data = try JSONEncoder().encode(message)
        guard let string = String(data: data, encoding: .utf8) else {
            throw DataConversionError.dataToStringFailed
        }
        return string
    }

}
