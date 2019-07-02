//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import Foundation

protocol WCHandshakeHandlerDelegate: class {
    func handler(_ handler: WCHandshakeHandler, didEstablishHandshake: Bool)
}

class WCHandshakeHandler: RequestHandler {

    private weak var delegate: WCHandshakeHandlerDelegate!

    init(delegate: WCHandshakeHandlerDelegate) {
        self.delegate = delegate
    }

    func canHandle(request: Request) -> Bool {
        return request.payload.method == "wc_sessionRequest"
    }

    func handle(request: Request) {
        // create Session object
        // TODO: convert request to json and init Session object from it
        guard let requiredParams = request.payload.params,
            case JSONRPC_2_0.Request.Params.named(let params) = requiredParams,
            let requiredPeerId = params["peerId"],
            case JSONRPC_2_0.ValueType.string(let peerId) = requiredPeerId,
            let requiredClientMeta = params["peerMeta"],
            case JSONRPC_2_0.ValueType.object(let clientMeta) = requiredClientMeta else { return }
        
        // delegate did establish handshake
        // peerId
        // peerMeta
        // response
        // server.disconnect()
        // server.connect
        // server.send(response)


    }

}
