//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import UIKit
import WalletConnectSwift

class ActionsViewController: UIViewController {

    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var personalSignButton: UIButton!
    @IBOutlet weak var ethSignButton: UIButton!
    @IBOutlet weak var ethSignTypedDataButton: UIButton!
    @IBOutlet weak var ethSendTransactionButton: UIButton!
    @IBOutlet weak var ethSignTransactionButton: UIButton!
    @IBOutlet weak var ethSendRawTransactionButton: UIButton!
    @IBOutlet weak var ethCustomRequestButton: UIButton!

    var client: Client!
    var session: Session!

    static func create(walletConnect: WalletConnect) -> ActionsViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let controller = storyboard.instantiateViewController(withIdentifier: "ActionsViewController") as! ActionsViewController
        controller.client = walletConnect.client
        controller.session = walletConnect.session
        return controller
    }

    var walletAccount: String {
        return session.walletInfo!.accounts[0]
    }

    @IBAction func disconnect(_ sender: Any) {
        guard let session = session else { return }
        try? client.disconnect(from: session)
    }

    @IBAction func personal_sign(_ sender: Any) {
        try? client.personal_sign(url: session.url, message: "0x01", account: session.walletInfo!.accounts[0]) {
            [weak self] response in
            self?.handleReponse(response, expecting: "Signature")
        }
    }

    @IBAction func eth_sign(_ sender: Any) {
        try? client.eth_sign(url: session.url, account: session.walletInfo!.accounts[0], message: "0x01") {
            [weak self] response in
            self?.handleReponse(response, expecting: "Signature")
        }
    }

    @IBAction func eth_signTypedData(_ sender: Any) {
        try? client.eth_signTypedData(url: session.url,
                                      account: session.walletInfo!.accounts[0],
                                      message: Stub.typedData) {
            [weak self] response in
            self?.handleReponse(response, expecting: "Signature") }
    }

    @IBAction func eth_sendTransaction(_ sender: Any) {
        try? client.send(nonceRequest()) { [weak self] response in
            guard let self = self, let nonce = self.nonce(from: response) else { return }
            let transaction = Stub.transaction(from: self.walletAccount, nonce: nonce)
            try? self.client.eth_sendTransaction(url: response.url, transaction: transaction) { [weak self] response in
                self?.handleReponse(response, expecting: "Hash")
            }
        }

    }

    @IBAction func eth_signTransaction(_ sender: Any) {
        try? client.send(nonceRequest()) { [weak self] response in
            guard let self = self, let nonce = self.nonce(from: response) else { return }
            let transaction = Stub.transaction(from: self.walletAccount, nonce: nonce)
            try? self.client.eth_signTransaction(url: response.url, transaction: transaction) { [weak self] response in
                self?.handleReponse(response, expecting: "Signature")
            }
        }
    }

    @IBAction func eth_sendRawTransaction(_ sender: Any) {
        try? client.eth_sendRawTransaction(url: session.url, data: Stub.data) { [weak self] response in
            self?.handleReponse(response, expecting: "Hash")
        }
    }

    @IBAction func customRequest(_ sender: Any) {
        try? client.send(gasPriceRequest()) { [weak self] response in
            self?.handleReponse(response, expecting: "Gas Price")
        }
    }

    @IBAction func close(_ sender: Any) {
        dismiss(animated: true)
    }


    private func handleReponse(_ response: Response, expecting: String) {
        var alert: UIAlertController
        switch response.payload.result {
        case .value(let value):
            guard case .string(let result) = value else { return }
            alert = UIAlertController(title: expecting, message: result, preferredStyle: .alert)
        case .error(let error):
            alert = UIAlertController(title: "Error", message: error.message, preferredStyle: .alert)
        }
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(alert, animated: true)
    }

    private func gasPriceRequest() -> Request {
        let payload = JSONRPC_2_0.Request(method: "eth_gasPrice",
                                          params: .positional([]),
                                          id: .string(UUID().uuidString))
        return Request(payload: payload, url: session.url)
    }

    private func nonceRequest() -> Request {
        let payload = JSONRPC_2_0.Request(method: "eth_getTransactionCount",
                                          params: .positional([.string(session.walletInfo!.accounts[0]),
                                                               .string("latest")]),
                                          id: .string(UUID().uuidString))
        return Request(payload: payload, url: session.url)
    }

    private func nonce(from response: Response) -> String? {
        switch response.payload.result {
        case .value(let value):
            guard case .string(let result) = value else { return nil }
            return result
        case .error(_):
            return nil
        }
    }

}

fileprivate enum Stub {

    /// https://docs.walletconnect.org/json-rpc/ethereum#example-parameters
    static let typedData = """
[
  "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826",
  {
    "types": {
      "EIP712Domain": [
        {
          "name": "name",
          "type": "string"
        },
        {
          "name": "version",
          "type": "string"
        },
        {
          "name": "chainId",
          "type": "uint256"
        },
        {
          "name": "verifyingContract",
          "type": "address"
        }
      ],
      "Person": [
        {
          "name": "name",
          "type": "string"
        },
        {
          "name": "wallet",
          "type": "address"
        }
      ],
      "Mail": [
        {
          "name": "from",
          "type": "Person"
        },
        {
          "name": "to",
          "type": "Person"
        },
        {
          "name": "contents",
          "type": "string"
        }
      ]
    },
    "primaryType": "Mail",
    "domain": {
      "name": "Ether Mail",
      "version": "1",
      "chainId": 1,
      "verifyingContract": "0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC"
    },
    "message": {
      "from": {
        "name": "Cow",
        "wallet": "0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826"
      },
      "to": {
        "name": "Bob",
        "wallet": "0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB"
      },
      "contents": "Hello, Bob!"
    }
  }
]
"""

    /// https://docs.walletconnect.org/json-rpc/ethereum#example-parameters-1
    static func transaction(from address: String, nonce: String) -> Client.Transaction {
        return Client.Transaction(from: address,
                                  to: "0xd46e8dd67c5d32be8058bb8eb970870f07244567",
                                  data: "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f072445675",
                                  gasLimit: "0x76c0", // 30400
            gasPrice: "0x9184e72a000", // 10000000000000
            value: "0x9184e72a", // 2441406250
            nonce: nonce)
    }

    /// https://docs.walletconnect.org/json-rpc/ethereum#example-5
    static let data = "0xd46e8dd67c5d32be8d46e8dd67c5d32be8058bb8eb970870f072445675058bb8eb970870f07244567"

}

