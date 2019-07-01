//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

// this is default WC handler proivded by lib
class WCHandshakeHandler: RequestHandler {

    weak var server: Server!

    struct Session {}

    func canHandle(request: Request) -> Bool {
        return request.method == "wc_sessionRequest"
    }

    func handle(request: Request) {
        // peerId
        // peerMeta
        // response
        // server.disconnect()
        // server.connect
        // server.send(response)
    }

}
