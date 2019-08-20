//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import UIKit
import AVFoundation

protocol ScannerViewControllerDelegate {
    func didScan(_ code: String)
}

class ScannerViewController: UIViewController {

    let captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var delegate: ScannerViewControllerDelegate!

    static func create(delegate: ScannerViewControllerDelegate) -> ScannerViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let controller = storyboard.instantiateViewController(withIdentifier: "ScannerViewController") as! ScannerViewController
        controller.delegate = delegate
        return controller
    }

    @IBAction func close(_ sender: Any) {
        dismiss(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera], mediaType: .video, position: .back)
        guard let captureDevice = deviceDiscoverySession.devices.first,
            let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(captureMetadataOutput)
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        captureMetadataOutput.metadataObjectTypes = [.qr]
        captureSession.startRunning()

        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = view.layer.bounds
        view.layer.insertSublayer(videoPreviewLayer, at: 0)        
    }

}

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !metadataObjects.isEmpty else { return }
        let metadata = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        if metadata.type == .qr && metadata.stringValue != nil {
            delegate.didScan(metadata.stringValue!)
        }
    }

}
