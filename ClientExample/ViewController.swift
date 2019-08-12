//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import UIKit
import WalletConnectSwift

class ViewController: UIViewController {

    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var personalSignButton: UIButton!

    var client: Client!
    var session: Session?

    @IBAction func disconnect(_ sender: Any) {
        guard let session = session else { return }
        try? client.disconnect(from: session)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // default bridge: https://safe-walletconnect.gnosis.io
        // test bridge with latest protocol version: https://bridge.walletconnect.org
        let wcUrl =  WCURL(topic: UUID().uuidString,
                           bridgeURL: URL(string: "https://bridge.walletconnect.org")!,
                           key: try! randomKey())
        let clientMeta = Session.ClientMeta(name: "ExampleDApp",
                                            description: "WalletConnectSwift ",
                                            icons: [],
                                            url: URL(string: "https://safe.gnosis.io")!)
        let dAppInfo = Session.DAppInfo(peerId: UUID().uuidString, peerMeta: clientMeta)
        client = Client(delegate: self, dAppInfo: dAppInfo)

        print("WalletConnect URL: \(wcUrl.absoluteString)")
        infoLabel.text = wcUrl.absoluteString
        infoLabel.isUserInteractionEnabled = true
        infoLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyUrl)))
        disableButtons()

        try! client.connect(url: wcUrl)
    }

    private func disableButtons() {
        disconnectButton.isEnabled = false
        personalSignButton.isEnabled = false
    }

    private func enableButtons() {
        disconnectButton.isEnabled = true
        personalSignButton.isEnabled = true
    }

    @objc private func copyUrl() {
        UIPasteboard.general.string = infoLabel.text
        let alert = UIAlertController(title: "Copied", message: nil, preferredStyle: .alert)
        show(alert)
    }

    // https://developer.apple.com/documentation/security/1399291-secrandomcopybytes
    func randomKey() throws -> String {
        var bytes = [Int8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return Data(bytes: bytes, count: 32).toHexString()
        } else {
            // we don't care in example app
            enum TestError: Error {
                case unknown
            }
            throw TestError.unknown
        }
    }

}

extension ViewController: ClientDelegate {

    func client(_ client: Client, didFailToConnect url: WCURL) {
        let alert = UIAlertController(title: "Failed to connect", message: nil, preferredStyle: .alert)
        show(alert)
    }

    func client(_ client: Client, didConnect session: Session) {
        self.session = session
        DispatchQueue.main.async {
            self.infoLabel.text = "Connected to: \(session.walletInfo!.accounts[0])"
            self.enableButtons()
        }
    }

    func client(_ client: Client, didDisconnect session: Session, error: Error?) {
        let alert = UIAlertController(title: "Did disconnect", message: nil, preferredStyle: .alert)
        show(alert) { [unowned self] in
            self.dismiss(animated: true)
        }
    }

    private func show(_ alert: UIAlertController, completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            self.present(alert, animated: true) {
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                    DispatchQueue.main.async {
                        alert.dismiss(animated: true) {
                            completion?()
                        }
                    }
                }
            }
        }
    }

}

