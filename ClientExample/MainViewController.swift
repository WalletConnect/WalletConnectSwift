//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {

    var handshakeController: HandshakeViewController!
    var actionsController: ActionsViewController!
    var walletConnect: WalletConnect!

    @IBAction func connect(_ sender: Any) {
        let connectionUrl = walletConnect.connect()
        handshakeController = HandshakeViewController.create(code: connectionUrl)
        present(handshakeController, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        walletConnect = WalletConnect(delegate: self)
    }

}

extension MainViewController: WalletConnectDelegate {

    func failedToConnect() {
        if let handshakeController = handshakeController {
            handshakeController.dismiss(animated: true)
        }
        UIAlertController.showFailedToConnect(from: self)
    }

    func didConnect() {
        actionsController = ActionsViewController.create(walletConnect: walletConnect)
        if let handshakeController = handshakeController {
            handshakeController.dismiss(animated: false)
        }
        present(actionsController, animated: false)
    }

    func didDisconnect() {
        if let presented = presentedViewController {
            presented.dismiss(animated: false)
        }
        UIAlertController.showDisconnected(from: self)
    }

}

extension UIAlertController {

    func withCloseButton() -> UIAlertController {
        addAction(UIAlertAction(title: "Close", style: .cancel))
        return self
    }

    static func showFailedToConnect(from controller: UIViewController) {
        let alert = UIAlertController(title: "Failed to connect", message: nil, preferredStyle: .alert)
        controller.present(alert.withCloseButton(), animated: true)
    }

    static func showDisconnected(from controller: UIViewController) {
        let alert = UIAlertController(title: "Did disconnect", message: nil, preferredStyle: .alert)
        controller.present(alert.withCloseButton(), animated: true)
    }

}
