//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import UIKit
import EthereumKit
import WalletConnectSwift

class MainViewController: UIViewController {

    @IBOutlet weak var walletAddressLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var scanQRCodeButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!

    var scannerController: ScannerViewController?
    var server: Server!

    @IBAction func scan(_ sender: Any) {
        scannerController = ScannerViewController.create(delegate: self)
        present(scannerController!, animated: true)
    }

    @IBAction func disconnect(_ sender: Any) {
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        server = Server(delegate: self)
    }

}

extension MainViewController: ServerDelegate {

    func server(_ server: Server, didFailToConnect url: WCURL) {
        print("WC: did fail to connect")
    }

    func server(_ server: Server, shouldStart session: Session, completion: (Session.WalletInfo) -> Void) {
        print("WC should start session")
    }

    func server(_ server: Server, didConnect session: Session) {
        print("WC: did connect")
    }

    func server(_ server: Server, didDisconnect session: Session) {
        print("WC: did disconnect")
    }

}

extension MainViewController: ScannerViewControllerDelegate {

    func didScan(_ code: String) {
        guard let url = WCURL(code) else { return }
        do {
            try server.connect(to: url)
        } catch {
            // TODO: show alert
            return
        }
        scannerController?.dismiss(animated: true)
    }

}
