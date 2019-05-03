//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import Foundation
import EthereumKit

public class EthereumKitEthereumService: EthereumService {

    public init() {}

    public func createMnemonic() -> [String] {
        return Mnemonic.create()
    }

    public func createSeed(mnemonic: [String]) -> Data {
        return (try? Mnemonic.createSeed(mnemonic: mnemonic)) ?? Data(repeating: 0, count: 32)
    }

    public func createHDPrivateKey(seed: Data, network: EIP155ChainId, derivedAt: Int) -> Data {
        let hdWallet = HDWallet(seed: seed, network: Network.private(chainID: network.rawValue, testUse: false))
        return try! hdWallet.privateKey(at: UInt32(derivedAt)).raw
    }

    public func createPublicKey(privateKey: Data) -> Data {
        return Crypto.generatePublicKey(data: privateKey, compressed: false)
    }

    public func createAddress(publicKey: Data) -> String {
        return PublicKey(raw: publicKey).address()
    }

}
