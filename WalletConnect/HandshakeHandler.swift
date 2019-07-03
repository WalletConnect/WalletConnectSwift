//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

protocol HandshakeHandlerDelegate: class {
    func handler(_ handler: HandshakeHandler, didReceiveRequestToCreateSession: Session)
}

class HandshakeHandler: RequestHandler {

    private weak var delegate: HandshakeHandlerDelegate!

    init(delegate: HandshakeHandlerDelegate) {
        self.delegate = delegate
    }

    func canHandle(request: Request) -> Bool {
        return request.payload.method == "wc_sessionRequest"
    }

    func handle(request: Request) {
        guard let session = try? Session(wcSessionRequest: request) else { return }
        delegate.handler(self, didReceiveRequestToCreateSession: session)
    }

}
