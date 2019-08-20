//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

protocol HandshakeHandlerDelegate: class {
    func handler(_ handler: HandshakeHandler, didReceiveRequestToCreateSession: Session, requestId: JSONRPC_2_0.IDType)
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
        // TODO: throw proper error
        guard let session = try? Session(wcSessionRequest: request),
            let requestId = request.payload.id else { return }
        delegate.handler(self, didReceiveRequestToCreateSession: session, requestId: requestId)
    }

}
