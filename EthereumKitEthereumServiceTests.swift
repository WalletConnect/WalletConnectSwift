//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import MultisigWalletImplementations

// swiftlint:disable line_length
class EthereumKitEthereumServiceTests: XCTestCase {

    let service = EthereumKitEthereumService()
    let mnemonic = ["guard", "argue", "language", "captain", "episode", "game", "leader", "iron", "anxiety", "wait", "like", "globe"]
    var seed: Data!
    var privteKey: Data!
    var publicKey: Data!

    override func setUp() {
        super.setUp()
        seed = service.createSeed(mnemonic: mnemonic)
        privteKey = service.createHDPrivateKey(seed: seed, network: EIP155ChainId.rinkeby, derivedAt: 0)
        publicKey = service.createPublicKey(privateKey: privteKey)
    }

    func test_createSeed() {
        XCTAssertEqual(seed.toHexString(), "da76293b113e41586f44da42de31458cec6640057b72184583016531e3ac97f18a65593404ee144ff23a216b5c177a4627e68958967380e3d11ebf51ba59ba2b")
    }

    func test_createHDPrivateKey() {
        XCTAssertEqual(privteKey.toHexString(), "260ee6ebb569cadbd6b8b924997e90fad8b08dcc6829a1a38844700992818f7a")
        let privteKey_1 = service.createHDPrivateKey(seed: seed, network: EIP155ChainId.rinkeby, derivedAt: 1)
        XCTAssertEqual(privteKey_1.toHexString(), "f3bee937f227dbc619be72d10e61d4cd894ee64651a2e461a4208203b362a042")
    }

    func test_createPublicKey() {
        XCTAssertEqual(publicKey.toHexString(), "047e2dcfda5d336e6630c8bfeb908962fc9bd5c528befd3e5e8191e9f6bf94c753a4b4699c12cbf8510c47b5693d51e4b97a79482e3a15c400404fced86e2952b0")
    }

    func test_createAddress() {
        let address = service.createAddress(publicKey: publicKey)
        XCTAssertEqual(address.toHexString(), "307845383233366438624245633530326166323136303435396432394361333863623063326637343843")
    }

    func test_whenCreatingPrivateKeyFromMetamaskMnemonic_thenItIsTheSame() {
        let metamaskMnemonic = ["gesture", "photo", "matrix", "enough", "stairs", "network", "private", "circle", "polar", "diamond", "tourist", "infant"]
        let seed = service.createSeed(mnemonic: metamaskMnemonic)
        let privteKey = service.createHDPrivateKey(seed: seed, network: EIP155ChainId.rinkeby, derivedAt: 0)
        let expectedPK = Data(hex: "94356f316b77e96e73d920a790c5d7ba7ab7af4525f9ef5f759d111e61a79070")
        XCTAssertEqual(privteKey, expectedPK)
    }

}
