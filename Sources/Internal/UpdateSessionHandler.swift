//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

protocol UpdateSessionHandlerDelegate: AnyObject {
    func handler(_ handler: UpdateSessionHandler, didUpdateSessionByURL: WCURL, sessionInfo: SessionInfo)
}

class UpdateSessionHandler: RequestHandler {
    private weak var delegate: UpdateSessionHandlerDelegate?

    init(delegate: UpdateSessionHandlerDelegate) {
        self.delegate = delegate
    }

    func canHandle(request: Request) -> Bool {
        return request.method == "wc_sessionUpdate"
    }

    func handle(request: Request) {
        do {
            let sessionInfo = try request.parameter(of: SessionInfo.self, at: 0)
            delegate?.handler(self, didUpdateSessionByURL: request.url, sessionInfo: sessionInfo)
        } catch {
            LogService.shared.log("WC: wrong format of wc_sessionUpdate request: \(error)")
            // TODO: send error response
        }
    }
}

/// https://docs.walletconnect.org/tech-spec#session-update
struct SessionInfo: Decodable {
    var approved: Bool
    var accounts: [String]?
    var chainId: Int?
}

enum ChainID {
    static let mainnet = 1
}
