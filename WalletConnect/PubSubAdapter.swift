//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

class PubSubAdapter {

    struct Message: Codable {

        var topic: String
        var type: MessageType
        var payload: String

        enum MessageType: String, Codable {
            case pub
            case sub
        }

    }

    enum AdapterError: Error {
        case stringToMessageFailed
        case messageToStringFailed
    }

    func message(from string: String) throws -> Message {
        guard let data = string.data(using: .utf8) else {
            throw AdapterError.stringToMessageFailed
        }
        return try JSONDecoder().decode(Message.self, from: data)
    }

    func string(from message: Message) throws -> String {
        let data = try JSONEncoder().encode(message)
        guard let string = String(data: data, encoding: .utf8) else {
            throw AdapterError.messageToStringFailed
        }
        return string
    }

}
