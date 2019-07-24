//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

protocol UpdateSessionHandlerDelegate: class {
    func handler(_ handler: UpdateSessionHandler, didUpdateSessionByURL: WCURL, approved: Bool)
}

class UpdateSessionHandler: RequestHandler {

    private weak var delegate: UpdateSessionHandlerDelegate?

    init(delegate: UpdateSessionHandlerDelegate) {
        self.delegate = delegate
    }

    func canHandle(request: Request) -> Bool {
        return request.payload.method == "wc_sessionUpdate"
    }

    func handle(request: Request) {
        // TODO: throw proper error
        guard let requiredArrayWrapper = request.payload.params,
            case JSONRPC_2_0.Request.Params.positional(let arrayWrapper) = requiredArrayWrapper, !arrayWrapper.isEmpty,
            case JSONRPC_2_0.ValueType.object(let params) = arrayWrapper[0],
            let requiredApproved = params["approved"],
            case JSONRPC_2_0.ValueType.bool(let approved) = requiredApproved else {
                let params = (try? request.payload.json().string) ?? "could not encode payload"
                print("WC: wrong format of wc_sessionUpdate request: \(params)")
                return
        }
        delegate?.handler(self, didUpdateSessionByURL: request.url, approved: approved)
    }

}
