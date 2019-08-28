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
    var session: Session!
    var wallet: Wallet!

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
        configureWallet()
        configureServer()
        walletAddressLabel.text = wallet.address()
        statusLabel.text = "Disconnected"
        disconnectButton.isHidden = true
    }

    private func configureServer() {
        server = Server(delegate: self)
        server.register(handler: PersonalSignHandler(for: self, server: server, wallet: wallet))
        server.register(handler: SignTransactionHandler(for: self, server: server, wallet: wallet))
        if let oldSessionObject = UserDefaults.standard.object(forKey: sessionKey) as? Data,
            let session = try? JSONDecoder().decode(Session.self, from: oldSessionObject) {
            try? server.reconnect(to: session)
        }
    }

    private func configureWallet() {
        let mnemonic = ["diagram", "myth", "surface", "whip", "mansion", "edit", "injury", "they", "want", "solid", "list", "outer"]
        let seed = try! Mnemonic.createSeed(mnemonic: mnemonic)
        wallet = try! Wallet(seed: seed, network: .private(chainID: 4, testUse: true), debugPrints: false)
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
    weak var wallet: Wallet!

    init(for controller: UIViewController, server: Server, wallet: Wallet) {
        self.controller = controller
        self.sever = server
        self.wallet = wallet
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
            let message = try request.parameter(of: String.self, at: 0)
            let address = try request.parameter(of: String.self, at: 1)

            guard address == wallet.address() else {
                sever.send(.reject(request))
                return
            }

            let decodedMessage = String(data: Data(hex: message), encoding: .utf8) ?? message

            askToSign(request: request, message: decodedMessage) {
                try! self.wallet.personalSign(message: decodedMessage)
            }
        } catch {
            sever.send(.invalid(request))
            return
        }
    }
}

class SignTransactionHandler: BaseHandler {

    override func canHandle(request: Request) -> Bool {
        return request.method == "eth_signTransaction"
    }

    struct SignTransaction: Decodable {
        var from: String
        var to: String?
        var data: String
        var gasLimit: String?
        var gasPrice: String?
        var value: String?
        var nonce: String?
    }

    override func handle(request: Request) {
        do {
            let param = try request.parameter(of: SignTransaction.self, at: 0)

            let wei: String = param.value == nil ? "0" :
                (param.value!.hasPrefix("0x") ? String(param.value!.dropFirst(2)) : param.value!)

            let transaction = RawTransaction(wei: wei,
                                             to: param.to ?? "0x",
                                             gasPrice: intFromHex(param.gasPrice ?? "0x"),
                                             gasLimit: intFromHex(param.gasLimit ?? "0x"),
                                             nonce: intFromHex(param.nonce ?? "0x"),
                                             data: Data(hex: param.data))
            let from = param.from

            guard from == self.wallet.address() else {
                self.sever.send(.reject(request))
                return
            }

            askToSign(request: request, message: transaction.description) {
                try! self.wallet.sign(rawTransaction: transaction)
            }
        } catch {
            self.sever.send(.invalid(request))
        }
    }

    private func intFromHex(_ hex: String) -> Int {
        if hex.hasPrefix("0x") {
            return Int(hex.suffix(hex.count - 2), radix: 16)!
        } else {
            return Int(hex, radix: 16)!
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
                                            accounts: [wallet.address()],
                                            chainId: 4,
                                            peerId: UUID().uuidString,
                                            peerMeta: walletMeta)
        onMainThread {
            UIAlertController.showShouldStart(from: self, clientName: session.dAppInfo.peerMeta.name) { [unowned self] in
                completion(walletInfo)
                self.scanQRCodeButton.isEnabled = false
            }
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
        do {
            try server.connect(to: url)
        } catch {
            return
        }
        scannerController?.dismiss(animated: true)
    }

}

extension UIAlertController {

    func withCloseButton(title: String = "Close", onClose: (() -> Void)? = nil ) -> UIAlertController {
        addAction(UIAlertAction(title: title, style: .cancel) { _ in onClose?() } )
        return self
    }

    static func showShouldStart(from controller: UIViewController, clientName: String, onStart: @escaping () -> Void) {
        let alert = UIAlertController(title: "Request to start a session", message: clientName, preferredStyle: .alert)
        let startAction = UIAlertAction(title: "Start", style: .default) { _ in onStart() }
        alert.addAction(startAction)
        controller.present(alert.withCloseButton(), animated: true)
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

extension RawTransaction {

    var description: String {
        return "to: \(to.string), value: \(value), gasPrice: \(gasPrice), gasLimit: \(gasLimit), data: \(data), nonce: \(nonce)"
    }

}
