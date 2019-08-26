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
        server.register(handler: RequestsHandler(for: self, server: server, wallet: wallet))
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

    class RequestsHandler: RequestHandler {

        weak var controller: UIViewController!
        weak var sever: Server!
        weak var wallet: Wallet!

        init(for controller: UIViewController, server: Server, wallet: Wallet) {
            self.controller = controller
            self.sever = server
            self.wallet = wallet
        }

        let allowedRequests = [
            "personal_sign",
            "eth_signTransaction"
        ]

        func canHandle(request: Request) -> Bool {
            return allowedRequests.contains(request.payload.method)
        }

        func handle(request: Request) {
            DispatchQueue.main.async {
                switch request.payload.method {
                case "personal_sign":
                    guard let (message, address) = self.signParams(from: request) else {
                        self.sever.send(self.missingRequiredParametersResponse(for: request))
                        return
                    }
                    guard address == self.wallet.address() else {
                        self.sever.send(self.rejectResponse(for: request))
                        return
                    }
                    let decodedMessage = String(data: Data(hex: message), encoding: .utf8) ?? message
                    UIAlertController.showShouldSign(from: self.controller,
                                                     title: "Request to sign a message",
                                                     message: decodedMessage,
                                                     onSign: {
                                                        let signature = try! self.wallet.personalSign(message: decodedMessage)
                                                        self.sever.send(self.approveResponse(for: request, signature: signature))
                    }, onCancel: {
                        self.sever.send(self.rejectResponse(for: request))
                    })
                case "eth_signTransaction":
                    guard let (from, transaction) = self.signTransaction(from: request) else {
                        self.sever.send(self.missingRequiredParametersResponse(for: request))
                        return
                    }
                    guard from == self.wallet.address() else {
                        self.sever.send(self.rejectResponse(for: request))
                        return
                    }
                    UIAlertController.showShouldSign(from: self.controller,
                                                     title: "Request to sign a transaction",
                                                     message: transaction.description,
                                                     onSign: {
                                                        let signature = try! self.wallet.sign(rawTransaction: transaction)
                                                        self.sever.send(self.approveResponse(for: request, signature: signature))
                    }, onCancel: {
                        self.sever.send(self.rejectResponse(for: request))
                    })
                default:
                    preconditionFailure("this should never happen")
                }
            }
        }

        private func signParams(from request: Request) -> (param1: String, param2: String)? {
            guard let params = request.payload.params,
                case JSONRPC_2_0.Request.Params.positional(let array) = params, array.count == 2,
                case JSONRPC_2_0.ValueType.string(let param1) = array[0],
                case JSONRPC_2_0.ValueType.string(let param2) = array[1] else {
                    return nil
            }
            return (param1, param2)
        }

        private func signTransaction(from request: Request) -> (from: String, transaction: RawTransaction)? {
            guard let params = request.payload.params,
                case JSONRPC_2_0.Request.Params.positional(let array) = params, array.count == 1,
                case JSONRPC_2_0.ValueType.object(let object) = array[0],
                let fromValueType = object["from"],
                case JSONRPC_2_0.ValueType.string(let from) = fromValueType,
                let toValueType = object["to"],
                case JSONRPC_2_0.ValueType.string(let to) = toValueType,
                let dataValueType = object["data"],
                case JSONRPC_2_0.ValueType.string(let data) = dataValueType,
                let gasLimitValueType = object["gasLimit"],
                case JSONRPC_2_0.ValueType.string(let gasLimit) = gasLimitValueType,
                let gasPriceValueType = object["gasPrice"],
                case JSONRPC_2_0.ValueType.string(let gasPrice) = gasPriceValueType,
                let valueValueType = object["value"],
                case JSONRPC_2_0.ValueType.string(let value) = valueValueType,
                let nonceValueType = object["nonce"],
                case JSONRPC_2_0.ValueType.string(let nonce) = nonceValueType else { return nil }

            let transaction = RawTransaction(wei: value.hasPrefix("0x") ? String(value.suffix(value.count - 2)) : value,
                                             to: to,
                                             gasPrice: intFromHex(gasPrice),
                                             gasLimit: intFromHex(gasLimit),
                                             nonce: intFromHex(nonce),
                                             data: Data(hex: data))
            return (from, transaction)
        }

        private func intFromHex(_ hex: String) -> Int {
            if hex.hasPrefix("0x") {
                return Int(hex.suffix(hex.count - 2), radix: 16)!
            } else {
                return Int(hex, radix: 16)!
            }
        }

        func missingRequiredParametersResponse(for request: Request) -> Response {
            let code = try! JSONRPC_2_0.Response.Payload.ErrorPayload.Code(-100500)
            let payload = JSONRPC_2_0.Response.Payload.ErrorPayload(code: code, message: "Missing required parameters in request", data: nil)
            return Response(payload: .init(result: .error(payload), id: request.payload.id ?? .null), url: request.url)
        }

        func rejectResponse(for request: Request) -> Response {
            let code = try! JSONRPC_2_0.Response.Payload.ErrorPayload.Code(-100501)
            let payload = JSONRPC_2_0.Response.Payload.ErrorPayload(code: code, message: "The request was rejected", data: nil)
            return Response(payload: .init(result: .error(payload), id: request.payload.id ?? .null), url: request.url)
        }

        func approveResponse(for request: Request, signature: String) -> Response {
            return Response(payload: .init(result: .value(.string(signature)), id: request.payload.id!), url: request.url)
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
