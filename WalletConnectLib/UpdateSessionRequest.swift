//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

/// https://docs.walletconnect.org/tech-spec#session-update
public class UpdateSessionRequest: Request {

    public init(url: WCURL, walletInfo: Session.WalletInfo) throws {
        let data = try JSONEncoder().encode([walletInfo])
        let params = try JSONDecoder().decode(JSONRPC_2_0.Request.Params.self, from: data)
        super.init(payload: JSONRPC_2_0.Request(method: "wc_sessionUpdate", params: params, id: nil), url: url)
    }

}
