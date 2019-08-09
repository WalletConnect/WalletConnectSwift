//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

/// https://docs.walletconnect.org/tech-spec#session-request
public class CreateSessionRequest: Request {

    public init?(url: WCURL, dAppInfo: Session.DAppInfo, id: JSONRPC_2_0.IDType) throws {
        let data = try JSONEncoder().encode([dAppInfo])
        let params = try JSONDecoder().decode(JSONRPC_2_0.Request.Params.self, from: data)
        super.init(payload: JSONRPC_2_0.Request(method: "wc_sessionRequest", params: params, id: id), url: url)
    }

}
