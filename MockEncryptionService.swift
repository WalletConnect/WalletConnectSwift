//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import Foundation
import MultisigWalletDomainModel
import BigInt

public class MockEncryptionService: EncryptionDomainService {

    // NOTE: contractAddress and ecdsaRandomS are connected - you'll need to regenerate address
    // if you change random number
    public func contractAddress(from: EthSignature, for transaction: EthTransaction) -> String? {
        return "0x8c89eb758AF5Ee056Bc251328105F8893B057A05"
    }

    public var extensionAddress: String?

    public var sign_output = EthSignature(r: "", s: "", v: 27)
    public var sign_input: (message: String, privateKey: PrivateKey)?

    public init() {}

    public func address(browserExtensionCode: String) -> String? {
        return extensionAddress
    }

    public func generateExternallyOwnedAccount() -> ExternallyOwnedAccount {
        return ExternallyOwnedAccount(address: Address("0xcccccccccccccccccccccccccccccccccccccccc"),
                                      mnemonic: Mnemonic(words: ["one", "two", "three"]),
                                      privateKey: PrivateKey(data: Data()),
                                      publicKey: PublicKey(data: Data()))
    }

    public func ecdsaRandomS() -> BigUInt {
        return BigUInt("1809251394333065553493296640760748560207343510400633813116524750123642650623")
    }

    public func sign(message: String, privateKey: PrivateKey) -> EthSignature {
        sign_input = (message, privateKey)
        return sign_output
    }

    public var hash_of_tx_output: Data = Data(repeating: 1, count: 32)

    public func hash(of transaction: Transaction) -> Data {
        return hash_of_tx_output
    }

    public var addressFromHashSignature_output: String?

    public func address(hash: Data, signature: EthSignature) -> String? {
        return addressFromHashSignature_output
    }

    public var dataFromSignature_output: Data = Data()

    public func data(from signature: EthSignature) -> Data {
        return dataFromSignature_output
    }

    public var signTransactionPrivateKey_output: Data = Data()

    public func sign(transaction: Transaction, privateKey: PrivateKey) -> Data {
        return signTransactionPrivateKey_output
    }

    public var addressFromStringResult: Address?

    public func address(from string: String) -> Address? {
        return addressFromStringResult ?? Address(string)
    }

    public var hash_output = Data(repeating: 3, count: 32)
    public var hash_input: Data?

    public func hash(_ data: Data) -> Data {
        hash_input = data
        return hash_output
    }

    public func ethSignature(from signature: Signature) -> EthSignature {
        return EthSignature(r: "0", s: "0", v: 27)
    }

    private var expected_deriveExternallyOwnedAccount =
        [(account: ExternallyOwnedAccount, index: Int, result: ExternallyOwnedAccount)]()
    private var actual_deriveExternallyOwnedAccount =
        [(account: ExternallyOwnedAccount, index: Int)]()

    public func expect_deriveExternallyOwnedAccount(from account: ExternallyOwnedAccount,
                                                    at pathIndex: Int,
                                                    result: ExternallyOwnedAccount) {
        expected_deriveExternallyOwnedAccount.append((account, pathIndex, result))
    }

    public func deriveExternallyOwnedAccount(from account: ExternallyOwnedAccount,
                                             at pathIndex: Int) -> ExternallyOwnedAccount {
        actual_deriveExternallyOwnedAccount.append((account, pathIndex))
        return expected_deriveExternallyOwnedAccount[actual_deriveExternallyOwnedAccount.count - 1].result
    }

    public var deriveExternallyOwnedAccountFromMnemonicResult: ExternallyOwnedAccount?
    public func deriveExternallyOwnedAccount(from mnemonic: String) -> ExternallyOwnedAccount? {
        return deriveExternallyOwnedAccountFromMnemonicResult
    }

}
