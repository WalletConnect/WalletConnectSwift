//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import UIKit
import Web3
import WalletConnectSwift

class MainViewController: UIViewController {
    @IBOutlet weak var walletAddressLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var scanQRCodeButton: UIButton!
    @IBOutlet weak var disconnectButton: UIButton!

    var scannerController: ScannerViewController?
    var server: Server!
    var session: Session!
    let privateKey: EthereumPrivateKey = try! EthereumPrivateKey()

    let sessionKey = "sessionKey"

    @IBAction func scan(_ sender: Any) {
        scannerController = ScannerViewController.create(delegate: self)
        present(scannerController!, animated: true)
    }

    @IBAction func disconnect(_ sender: Any) {
        try! server.disconnect(from: session)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureServer()
        walletAddressLabel.text = privateKey.address.hex(eip55: true)
        statusLabel.text = "Disconnected"
        disconnectButton.isHidden = true
    }

    private func configureServer() {
        server = Server(delegate: self)
        server.register(handler: PersonalSignHandler(for: self, server: server, privateKey: privateKey))
        server.register(handler: SignTransactionHandler(for: self, server: server, privateKey: privateKey))
        if let oldSessionObject = UserDefaults.standard.object(forKey: sessionKey) as? Data,
            let session = try? JSONDecoder().decode(Session.self, from: oldSessionObject) {
            try? server.reconnect(to: session)
        }
    }

    func onMainThread(_ closure: @escaping () -> Void) {
        if Thread.isMainThread {
            closure()
        } else {
            DispatchQueue.main.async {
                closure()
            }
        }
    }
}

class BaseHandler: RequestHandler {
    weak var controller: UIViewController!
    weak var sever: Server!
    weak var privateKey: EthereumPrivateKey!

    init(for controller: UIViewController, server: Server, privateKey: EthereumPrivateKey) {
        self.controller = controller
        self.sever = server
        self.privateKey = privateKey
    }

    func canHandle(request: Request) -> Bool {
        return false
    }

    func handle(request: Request) {
        // to override
    }

    func askToSign(request: Request, message: String, sign: @escaping () -> String) {
        let onSign = {
            let signature = sign()
            self.sever.send(.signature(signature, for: request))
        }
        let onCancel = {
            self.sever.send(.reject(request))
        }
        DispatchQueue.main.async {
            UIAlertController.showShouldSign(from: self.controller,
                                             title: "Request to sign a message",
                                             message: message,
                                             onSign: onSign,
                                             onCancel: onCancel)
        }
    }
}

class PersonalSignHandler: BaseHandler {
    override func canHandle(request: Request) -> Bool {
        return request.method == "personal_sign"
    }

    override func handle(request: Request) {
        do {
            let messageBytes = try request.parameter(of: String.self, at: 0)
            let address = try request.parameter(of: String.self, at: 1)

            guard address == privateKey.address.hex(eip55: true) else {
                sever.send(.reject(request))
                return
            }

            let decodedMessage = String(data: Data(hex: messageBytes), encoding: .utf8) ?? messageBytes

            askToSign(request: request, message: decodedMessage) {
                let personalMessageData = self.personalMessageData(messageData: Data(hex: messageBytes))
                let (v, r, s) = try! self.privateKey.sign(message: .init(hex: personalMessageData.toHexString()))
                return "0x" + r.toHexString() + s.toHexString() + String(v + 27, radix: 16) // v in [0, 1]
            }
        } catch {
            sever.send(.invalid(request))
            return
        }
    }

    private func personalMessageData(messageData: Data) -> Data {
        let prefix = "\u{19}Ethereum Signed Message:\n"
        let prefixData = (prefix + String(messageData.count)).data(using: .ascii)!
        return prefixData + messageData
    }
}

class SignTransactionHandler: BaseHandler {
    override func canHandle(request: Request) -> Bool {
        return request.method == "eth_signTransaction"
    }

    override func handle(request: Request) {
        do {
            let transaction = try request.parameter(of: EthereumTransaction.self, at: 0)
            guard transaction.from == privateKey.address else {
                self.sever.send(.reject(request))
                return
            }

            askToSign(request: request, message: transaction.description) {
                let signedTx = try! transaction.sign(with: self.privateKey, chainId: 4)
                let (r, s, v) = (signedTx.r, signedTx.s, signedTx.v)
                return r.hex() + s.hex().dropFirst(2) + String(v.quantity, radix: 16)
            }
        } catch {
            self.sever.send(.invalid(request))
        }
    }
}

extension Response {
    static func signature(_ signature: String, for request: Request) -> Response {
        return try! Response(url: request.url, value: signature, id: request.id!)
    }
}

extension MainViewController: ServerDelegate {
    func server(_ server: Server, didFailToConnect url: WCURL) {
        onMainThread {
            UIAlertController.showFailedToConnect(from: self)
        }
    }

    func server(_ server: Server, shouldStart session: Session, completion: @escaping (Session.WalletInfo) -> Void) {
        let walletMeta = Session.ClientMeta(name: "Test Wallet",
                                            description: nil,
                                            icons: [],
                                            url: URL(string: "https://safe.gnosis.io")!)
        let walletInfo = Session.WalletInfo(approved: true,
                                            accounts: [privateKey.address.hex(eip55: true)],
                                            chainId: 4,
                                            peerId: UUID().uuidString,
                                            peerMeta: walletMeta)
        onMainThread {
            UIAlertController.showShouldStart(from: self, clientName: session.dAppInfo.peerMeta.name, onStart: {
                completion(walletInfo)
            }, onClose: {
                completion(Session.WalletInfo(approved: false, accounts: [], chainId: 4, peerId: "", peerMeta: walletMeta))
                self.scanQRCodeButton.isEnabled = true
            })
        }
    }

    func server(_ server: Server, didConnect session: Session) {
        self.session = session
        let sessionData = try! JSONEncoder().encode(session)
        UserDefaults.standard.set(sessionData, forKey: sessionKey)
        onMainThread {
            self.scanQRCodeButton.isHidden = true
            self.disconnectButton.isHidden = false
            self.statusLabel.text = "Connected to \(session.dAppInfo.peerMeta.name)"
        }
    }

    func server(_ server: Server, didDisconnect session: Session) {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        onMainThread {
            self.scanQRCodeButton.isEnabled = true
            self.scanQRCodeButton.isHidden = false
            self.disconnectButton.isHidden = true
            self.statusLabel.text = "Disconnected"
        }
    }
}

extension MainViewController: ScannerViewControllerDelegate {
    func didScan(_ code: String) {
        guard let url = WCURL(code) else { return }
        scanQRCodeButton.isEnabled = false
        scannerController?.dismiss(animated: true) { [unowned self] in
            do {
                try self.server.connect(to: url)
            } catch {
                return
            }
        }
    }
}

extension UIAlertController {
    func withCloseButton(title: String = "Close", onClose: (() -> Void)? = nil ) -> UIAlertController {
        addAction(UIAlertAction(title: title, style: .cancel) { _ in onClose?() } )
        return self
    }

    static func showShouldStart(from controller: UIViewController, clientName: String, onStart: @escaping () -> Void, onClose: @escaping (() -> Void)) {
        let alert = UIAlertController(title: "Request to start a session", message: clientName, preferredStyle: .alert)
        let startAction = UIAlertAction(title: "Start", style: .default) { _ in onStart() }
        alert.addAction(startAction)
        controller.present(alert.withCloseButton(onClose: onClose), animated: true)
    }

    static func showFailedToConnect(from controller: UIViewController) {
        let alert = UIAlertController(title: "Failed to connect", message: nil, preferredStyle: .alert)
        controller.present(alert.withCloseButton(), animated: true)
    }

    static func showDisconnected(from controller: UIViewController) {
        let alert = UIAlertController(title: "Did disconnect", message: nil, preferredStyle: .alert)
        controller.present(alert.withCloseButton(), animated: true)
    }

    static func showShouldSign(from controller: UIViewController, title: String, message: String, onSign: @escaping () -> Void, onCancel: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let startAction = UIAlertAction(title: "Sign", style: .default) { _ in onSign() }
        alert.addAction(startAction)
        controller.present(alert.withCloseButton(title: "Reject", onClose: onCancel), animated: true)
    }
}

extension EthereumTransaction {
    var description: String {
        return """
        to: \(String(describing: to!.hex(eip55: true))),
        value: \(String(describing: value!.hex())),
        gasPrice: \(String(describing: gasPrice!.hex())),
        gas: \(String(describing: gas!.hex())),
        data: \(data.hex()),
        nonce: \(String(describing: nonce!.hex()))
        """
    }
}
