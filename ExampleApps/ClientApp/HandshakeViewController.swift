//
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import UIKit

class HandshakeViewController: UIViewController {
    @IBOutlet weak var qrCodeImageView: UIImageView!

    var code: String!

    static func create(code: String) -> HandshakeViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let controller = storyboard.instantiateViewController(withIdentifier: "HandshakeViewController") as! HandshakeViewController
        controller.code = code
        return controller
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let data = code.data(using: .ascii)
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(data, forKey: "inputMessage")
        let transform = CGAffineTransform(scaleX: 3, y: 3)
        qrCodeImageView.image = UIImage(ciImage: filter.outputImage!.transformed(by: transform))
    }

    @IBAction func close(_ sender: Any) {
        dismiss(animated: true)
    }
}
