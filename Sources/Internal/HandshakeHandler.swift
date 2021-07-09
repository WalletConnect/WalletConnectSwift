//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

protocol HandshakeHandlerDelegate: AnyObject {
    // TODO: instead of IDType, use RequestID
    func handler(_ handler: HandshakeHandler, didReceiveRequestToCreateSession: Session, requestId: RequestID)
}

class HandshakeHandler: RequestHandler {
    private weak var delegate: HandshakeHandlerDelegate?

    init(delegate: HandshakeHandlerDelegate) {
        self.delegate = delegate
    }

    func canHandle(request: Request) -> Bool {
        return request.method == "wc_sessionRequest"
    }

    func handle(request: Request) {
        do {
            let dappInfo = try request.parameter(of: Session.DAppInfo.self, at: 0)
            let session = Session(url: request.url, dAppInfo: dappInfo, walletInfo: nil)
            guard let requestID = request.id else {
                // TODO: request ID is required
                return
            }
            delegate?.handler(self, didReceiveRequestToCreateSession: session, requestId: requestID)
        } catch {
            // TODO: handle error
        }
    }
}
