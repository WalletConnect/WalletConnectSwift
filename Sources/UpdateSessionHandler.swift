//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

protocol UpdateSessionHandlerDelegate: class {
    func handler(_ handler: UpdateSessionHandler, didUpdateSessionByURL: WCURL, approved: Bool)
}

class UpdateSessionHandler: RequestHandler {

    private weak var delegate: UpdateSessionHandlerDelegate!

    init(delegate: UpdateSessionHandlerDelegate) {
        self.delegate = delegate
    }

    func canHandle(request: Request) -> Bool {
        return request.method == "wc_sessionUpdate"
    }

    func handle(request: Request) {
        do {
            let sessionInfo = try request.parameter(of: SessionInfo.self, at: 0)
            delegate.handler(self, didUpdateSessionByURL: request.url, approved: sessionInfo.approved)
        } catch {
            print("WC: wrong format of wc_sessionUpdate request: \(error)")
            // TODO: send error response
        }
    }

}

struct SessionInfo: Decodable {
    var approved: Bool
}
