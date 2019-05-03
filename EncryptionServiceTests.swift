//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import MultisigWalletImplementations
import MultisigWalletApplication
import EthereumKit
import Common
import MultisigWalletDomainModel
import CryptoSwift
import BigInt

class EncryptionServiceTests: XCTestCase {

    var encryptionService = EncryptionService()

    override func setUp() {
        super.setUp()
        ApplicationServiceRegistry.put(service: MockLogger(), for: Logger.self)
    }

    func test_extensionCodeWithValidJson() {
        let jsonData = JSON(extensionCode: QRCode.validCode1)
        let code = try! JSONDecoder().decode(ExtensionCode.self, from: jsonData)
        XCTAssertEqual(code.expirationDate, "2018-05-09T14:18:55+00:00")
        XCTAssertEqual(code.v, 27)
        XCTAssertEqual(code.r,
                       BInt("75119860711638973245538703589762310947594328712729260330312782656531560398776", radix: 10))
        XCTAssertEqual(code.s,
                       BInt("51392727032514077370236468627319183981033698696331563950328005524752791633785", radix: 10))
    }

    func test_extensionCodeWithInvalidJson() {
        let jsonData = JSON(extensionCode: QRCode.invalidCode1)
        let code = try? JSONDecoder().decode(ExtensionCode.self, from: jsonData)
        XCTAssertNil(code)
    }

    func test_address_whenValidCodeScanned_thenReturnsValidAddress() {
        guard let address1 = encryptionService.address(browserExtensionCode: QRCode.validCode1.code) else {
            XCTFail("Couldn't decode extension code for address 1")
            return
        }
        XCTAssertEqual(address1.uppercased(), QRCode.validCode1.address.uppercased())

        guard let address2 = encryptionService.address(browserExtensionCode: QRCode.validCode2.code) else {
            XCTFail("Couldn't decode extension code for address 2")
            return
        }
        XCTAssertEqual(address2.uppercased(), QRCode.validCode2.address.uppercased())
    }

    func test_address_whenInvalidCodeScanned_thenReturnedNil() {
        let address = encryptionService.address(browserExtensionCode: QRCode.invalidCode1.code)
        XCTAssertNil(address)
    }

    func test_whenExternallyOwnedAccountCreated_thenItIsCorrect() throws {
        let expectedAccount = ExternallyOwnedAccount.testAccount
        let ethereumService = CustomWordsEthereumService(words: expectedAccount.mnemonic.words)
        encryptionService = EncryptionService(chainId: .mainnet, ethereumService: ethereumService)

        let account = encryptionService.generateExternallyOwnedAccount()

        XCTAssertEqual(account, expectedAccount)
        XCTAssertEqual(account.address, expectedAccount.address)
        XCTAssertEqual(account.mnemonic, expectedAccount.mnemonic)
        XCTAssertEqual(account.privateKey, expectedAccount.privateKey)
        XCTAssertEqual(account.publicKey, expectedAccount.publicKey)
    }

    func test_whenDerivedExternallyOwnedAccountCreated_thenItIsCorrect() {
        let expectedMasterAccount = ExternallyOwnedAccount.testAccount
        let ethereumService = CustomWordsEthereumService(words: expectedMasterAccount.mnemonic.words)
        encryptionService = EncryptionService(chainId: .mainnet, ethereumService: ethereumService)
        let account = encryptionService.generateExternallyOwnedAccount()

        let derivedAccount = encryptionService.deriveExternallyOwnedAccount(from: account, at: 1)
        let expectedAccount = ExternallyOwnedAccount.testAccountAt1

        XCTAssertEqual(derivedAccount, expectedAccount)
        XCTAssertEqual(derivedAccount.address, expectedAccount.address)
        XCTAssertEqual(derivedAccount.mnemonic, expectedAccount.mnemonic)
        print(derivedAccount.privateKey.data.toHexString())
        XCTAssertEqual(derivedAccount.privateKey, expectedAccount.privateKey)
        print(derivedAccount.publicKey.data.toHexString())
        XCTAssertEqual(derivedAccount.publicKey, expectedAccount.publicKey)
        XCTAssertEqual(derivedAccount.derivedIndex, 1)
    }

    func test_whenSigningMessage_thenSignatureIsCorrect() throws {
        let pkData = Data(ethHex: "d0d3ae306602070917c456b61d88bee9dc74edb5853bb87b1c13e5bfa2c3d0d9")
        let privateKey = MultisigWalletDomainModel.PrivateKey(data: pkData)
        let message = "Gnosis"
        encryptionService = EncryptionService(chainId: .mainnet)

        let ethSignature = encryptionService.sign(message: message, privateKey: privateKey)
        XCTAssertEqual(ethSignature.r, "101211893217270431722518027522228002686666504049250244774157670632781156043183")
        XCTAssertEqual(ethSignature.s, "51602277827206092161359189523869407094850301206236947198082645428468309668322")
        XCTAssertEqual(ethSignature.v, 37)

        let signer = EIP155Signer(chainID: encryptionService.chainId.rawValue)
        let signature = signer.calculateSignature(r: BInt(ethSignature.r)!,
                                                  s: BInt(ethSignature.s)!,
                                                  v: BInt(ethSignature.v))

        // swiftlint:disable:next line_length
        XCTAssertEqual(signature.toHexString(), "dfc3e6c87132b3ef90b514041b7c77444d9d3f69b53c884e99fd37811b9dc9af7215daaf0fc1132306f7cb4223aa03e967ad6734f241bf17e0a33ced764db1e200")

        let publicKey = Crypto.generatePublicKey(data: pkData, compressed: true)
        let signedData = Crypto.hashSHA3_256(message.data(using: .utf8)!)
        let restoredPublicKey = Crypto.publicKey(signature: signature, of: signedData, compressed: true)!

        XCTAssertEqual(publicKey, restoredPublicKey)
    }


    func test_whenExtractingContractAddress_thenVerifiesSignature() throws {
        encryptionService = EncryptionService(chainId: .any)
        let result = encryptionService.contractAddress(from: ContractAddressFixture.signature,
                                                       for: ContractAddressFixture.transaction)
        XCTAssertEqual(result, ContractAddressFixture.contractAddress)
    }

    func test_signingRawTransactionOnAnyChainId() throws {
        encryptionService = EncryptionService(chainId: .any)
        let anyChainSignedTx = try encryptionService.sign(transaction: RawTransactionFixture.tx,
                                                          privateKey: RawTransactionFixture.privateKey)
        XCTAssertEqual(anyChainSignedTx.value, RawTransactionFixture.anyChainHash)

        encryptionService = EncryptionService(chainId: .rinkeby)
        let rinkebySignedTx = try encryptionService.sign(transaction: RawTransactionFixture.tx,
                                                         privateKey: RawTransactionFixture.privateKey)
        XCTAssertEqual(rinkebySignedTx.value, RawTransactionFixture.rinkebyHash)
    }

    // swiftlint:disable:next function_body_length
    func test_transactionHash_byParts() throws {
        let dataHashInput = oneline("561001057600080fd5b5060405161060a3803806106")
        let dataHash = keccak(dataHashInput)
        print(dataHashInput, dataHash)

        let domainHashInput = oneline("""
035aff83d86937d35b32e04f0ddc6ff469290eef2f1b692d8a815c89404d4749
000000000000000000000000092CC1854399ADc38Dad4f846E369C40D0a40307
""")
        let domainHash = keccak(domainHashInput)
        print(domainHashInput, domainHash)

        let valueHashInput = oneline("""
14d461bc7412367e924637b363c7bf29b8f47e2f84869f4426e5633d8af47b20
0000000000000000000000008e6A5aDb2B88257A3DAc7A76A7B4EcaCdA090b66
00000000000000000000000000000000000000000000000000000000000F42BB
ef8553f949acc5f0cb8002523b7a4f8e02664b6637eddc74ad72bb8e38588309
0000000000000000000000000000000000000000000000000000000000000001
0000000000000000000000000000000000000000000000000000000000005208
00000000000000000000000000000000000000000000000000000000000074F7
0000000000000000000000000000000000000000000000000000000005E87F39
0000000000000000000000001001230000000000000000000000000000000001
0000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000002DD7A9A70
""")
        let valueHash = keccak(valueHashInput)
        print(valueHashInput, valueHash)

        let txHashInput = "1901" + domainHash + valueHash
        let txHash = keccak(txHashInput)
        print(txHashInput, txHash)

        let data = TransactionHashingFixture.jsonArray.data(using: .utf8)!
        let fixtures = try JSONDecoder().decode([TransactionHashingFixture.Message].self, from: data)

        let tx = transaction(from: fixtures.last!)
        XCTAssertEqual(keccak(tx.data ?? Data()), dataHash)
        XCTAssertEqual(encryptionService.valueData(tx).toHexString().lowercased(), valueHashInput.lowercased())
        XCTAssertEqual(encryptionService.domainData(tx).toHexString().lowercased(), domainHashInput.lowercased())
        XCTAssertEqual(encryptionService.hashData(tx).toHexString().lowercased(), txHashInput.lowercased())
        XCTAssertEqual(encryptionService.hash(of: tx).toHexString().lowercased(), txHash.lowercased())
    }

    private func oneline(_ str: String) -> String {
        return str.replacingOccurrences(of: "\n", with: "")
    }

    private func keccak(_ v: String) -> String {
        return keccak(Data(ethHex: v))
    }

    private func keccak(_ v: Data) -> String {
        return encryptionService.hash(v).toHexString()
    }

    func test_hashOfTransaction() throws {
        let data = TransactionHashingFixture.jsonArray.data(using: .utf8)!
        let fixtures = try JSONDecoder().decode([TransactionHashingFixture.Message].self, from: data)
        fixtures.forEach { fixture in
            let transaction = self.transaction(from: fixture)
            let hexHash = encryptionService.hash(of: transaction).toHexString().addHexPrefix()
            XCTAssertEqual(hexHash, fixture.hash)
        }
    }

    private func transaction(from fixture: TransactionHashingFixture.Message) -> MultisigWalletDomainModel.Transaction {
        return newTransaction()
            .change(sender: Address(fixture.safe))
            .change(recipient: Address(fixture.to))
            .change(amount: .ether(TokenInt(fixture.value)!))
            .change(data: Data(ethHex: fixture.data))
            .change(operation: WalletOperation(rawValue: Int(fixture.operation)!)!)
            .change(nonce: fixture.nonce)
            .change(feeEstimate: TransactionFeeEstimate(gas: Int(fixture.txGas)!,
                                                        dataGas: Int(fixture.dataGas)!,
                                                        operationalGas: 0,
                                                        gasPrice: newGasPrice(fixture.gasPrice, fixture.gasToken)))
    }

    private func newTransaction() -> MultisigWalletDomainModel.Transaction {
        let walletID = WalletID()
        let accountID = AccountID(tokenID: Token.gno.id, walletID: walletID)
        return MultisigWalletDomainModel.Transaction(id: TransactionID(),
                                                     type: .transfer,
                                                     walletID: walletID,
                                                     accountID: accountID)
    }

    private func newGasPrice(_ price: String, _ token: String) -> TokenAmount {
        return TokenAmount(amount: TokenInt(price)!,
                           token: Token(code: "SOME",
                                        name: "SOME NAME",
                                        decimals: 18,
                                        address: Address(token),
                                        logoUrl: ""))
    }

    func test_addressFromString() {
        XCTAssertNil(encryptionService.address(from: ""))
        XCTAssertNil(encryptionService.address(from: "0x"))
        XCTAssertNil(encryptionService.address(from: "0x001"))
        XCTAssertEqual(encryptionService.address(from: "0x0000000000000000000000000000000000000000"),
                       MultisigWalletDomainModel.Address.zero)
        XCTAssertEqual(encryptionService.address(from: "0xF0C64662DA29EBF76C7B9BED3D7B02F2EABD52B9"),
                       MultisigWalletDomainModel.Address("0xf0C64662da29ebF76C7B9Bed3D7B02F2EAbD52B9"))
    }

}

extension EncryptionServiceTests {

    private func JSON(extensionCode: QRCode) -> Data {
        return extensionCode.code.data(using: .utf8)!
    }

}

// swiftlint:disable line_length
struct ContractAddressFixture {

    static let signature = EthSignature(r: "197968319015768475474728412290891320396909873147159586006855444916116598112",
                                        s: "61819997756830335013150358111721476328157622718490157315818634400316888446796",
                                        v: 27)
    static let transaction = EthTransaction(from: "0xf0C64662da29ebF76C7B9Bed3D7B02F2EAbD52B9",
                                            value: 0,
                                            data: "0x608060405234801561001057600080fd5b5060405161060a38038061060a833981018060405281019080805190602001909291908051820192919060200180519060200190929190805190602001909291908051906020019092919050505084848160008173ffffffffffffffffffffffffffffffffffffffff1614151515610116576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260248152602001807f496e76616c6964206d617374657220636f707920616464726573732070726f7681526020017f696465640000000000000000000000000000000000000000000000000000000081525060400191505060405180910390fd5b806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550506000815111156101a35773ffffffffffffffffffffffffffffffffffffffff60005416600080835160208501846127105a03f46040513d6000823e600082141561019f573d81fd5b5050505b5050600081111561036d57600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff1614156102b7578273ffffffffffffffffffffffffffffffffffffffff166108fc829081150290604051600060405180830381858888f1935050505015156102b2576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260268152602001807f436f756c64206e6f74207061792073616665206372656174696f6e207769746881526020017f206574686572000000000000000000000000000000000000000000000000000081525060400191505060405180910390fd5b61036c565b6102d1828483610377640100000000026401000000009004565b151561036b576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260268152602001807f436f756c64206e6f74207061792073616665206372656174696f6e207769746881526020017f20746f6b656e000000000000000000000000000000000000000000000000000081525060400191505060405180910390fd5b5b5b5050505050610490565b600060608383604051602401808373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001828152602001925050506040516020818303038152906040527fa9059cbb000000000000000000000000000000000000000000000000000000007bffffffffffffffffffffffffffffffffffffffffffffffffffffffff19166020820180517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff838183161783525050505090506000808251602084016000896127105a03f16040513d6000823e3d60008114610473576020811461047b5760009450610485565b829450610485565b8151158315171594505b505050509392505050565b61016b8061049f6000396000f30060806040526004361061004c576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680634555d5c91461008b5780635c60da1b146100b6575b73ffffffffffffffffffffffffffffffffffffffff600054163660008037600080366000845af43d6000803e6000811415610086573d6000fd5b3d6000f35b34801561009757600080fd5b506100a061010d565b6040518082815260200191505060405180910390f35b3480156100c257600080fd5b506100cb610116565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b60006002905090565b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff169050905600a165627a7a723058206d69a7317ea208981c1c60405cb41a930548e3d5a04a8d497e29ddc5e60223f200290000000000000000000000002aab3573ecfd2950a30b75b6f3651b84f4e130da00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000ab8c18e66135561676f0781555d05cf6b22024a30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f905e741cb1d800000000000000000000000000000000000000000000000000000000000001440ec78d9e00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000268bf7a7defcbfd7defd94f25f03f04b17efda310000000000000000000000006c60434fc786dec7fb03a7421e4014fa95da3e19000000000000000000000000daff896b02ee319d0f44af1533a0f48220283ade0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
                                            gas: "398260",
                                            gasPrice: "11000000000",
                                            nonce: 0)
    static let contractAddress = "0xF2Ce00Af37e883E03C54f3b56382Cc6F52fAE305"

}

struct TransactionHashingFixture {

    struct Message: Codable {
        var type: String
        var hash: String
        var safe: String
        var to: String
        var value: String
        var data: String
        var operation: String
        var txGas: String
        var dataGas: String
        var gasPrice: String
        var gasToken: String
        var nonce: String
    }

    static let jsonArray = """
[
{
    "type": "requestConfirmation",
    "hash": "0xddb1eadbe8d01cee43bc1756b16f8cfcd04c455fa1dec329890d39dd1f0c63d9",
    "safe": "0x092CC1854399ADc38Dad4f846E369C40D0a40307",
    "to": "0x8e6A5aDb2B88257A3DAc7A76A7B4EcaCdA090b66",
    "value": "1000123",
    "data": "",
    "operation": "0",
    "txGas": "21000",
    "dataGas": "0",
    "gasPrice": "99123001",
    "gasToken": "0x0000000000000000000000000000000000000000",
    "nonce": "1"
},
{
    "type": "requestConfirmation",
    "hash": "0x238b92e31ae74f0dd353b3a1fb3e014469e0a0fc09cb1d60f23bf098c929c97b",
    "safe": "0x092CC1854399ADc38Dad4f846E369C40D0a40307",
    "to": "0x0000000000000000000000000000000000000000",
    "value": "0",
    "data": "0x608060405234801561001057600080fd5b5060405161060a38038061060a833981018060405281019080805190602001909291908051820192919060200180519060200190929190805190602001909291908051906020019092919050505084848160008173ffffffffffffffffffffffffffffffffffffffff1614151515610116576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260248152602001807f496e76616c6964206d617374657220636f707920616464726573732070726f7681526020017f696465640000000000000000000000000000000000000000000000000000000081525060400191505060405180910390fd5b806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550506000815111156101a35773ffffffffffffffffffffffffffffffffffffffff60005416600080835160208501846127105a03f46040513d6000823e600082141561019f573d81fd5b5050505b5050600081111561036d57600073ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff1614156102b7578273ffffffffffffffffffffffffffffffffffffffff166108fc829081150290604051600060405180830381858888f1935050505015156102b2576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260268152602001807f436f756c64206e6f74207061792073616665206372656174696f6e207769746881526020017f206574686572000000000000000000000000000000000000000000000000000081525060400191505060405180910390fd5b61036c565b6102d1828483610377640100000000026401000000009004565b151561036b576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260268152602001807f436f756c64206e6f74207061792073616665206372656174696f6e207769746881526020017f20746f6b656e000000000000000000000000000000000000000000000000000081525060400191505060405180910390fd5b5b5b5050505050610490565b600060608383604051602401808373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001828152602001925050506040516020818303038152906040527fa9059cbb000000000000000000000000000000000000000000000000000000007bffffffffffffffffffffffffffffffffffffffffffffffffffffffff19166020820180517bffffffffffffffffffffffffffffffffffffffffffffffffffffffff838183161783525050505090506000808251602084016000896127105a03f16040513d6000823e3d60008114610473576020811461047b5760009450610485565b829450610485565b8151158315171594505b505050509392505050565b61016b8061049f6000396000f30060806040526004361061004c576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680634555d5c91461008b5780635c60da1b146100b6575b73ffffffffffffffffffffffffffffffffffffffff600054163660008037600080366000845af43d6000803e6000811415610086573d6000fd5b3d6000f35b34801561009757600080fd5b506100a061010d565b6040518082815260200191505060405180910390f35b3480156100c257600080fd5b506100cb610116565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b60006002905090565b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff169050905600a165627a7a723058206d69a7317ea208981c1c60405cb41a930548e3d5a04a8d497e29ddc5e60223f200290000000000000000000000002aab3573ecfd2950a30b75b6f3651b84f4e130da00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000ab8c18e66135561676f0781555d05cf6b22024a30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f905e741cb1d800000000000000000000000000000000000000000000000000000000000001440ec78d9e00000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000003000000000000000000000000268bf7a7defcbfd7defd94f25f03f04b17efda310000000000000000000000006c60434fc786dec7fb03a7421e4014fa95da3e19000000000000000000000000daff896b02ee319d0f44af1533a0f48220283ade0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    "operation": "2",
    "txGas": "21000",
    "dataGas": "398260",
    "gasPrice": "11000000000",
    "gasToken": "0x0000000000000000000000000000000000000000",
    "nonce": "2"
},
{
    "type": "requestConfirmation",
    "hash": "0x9fbfde51c1132c2a28fa482d30c66348e8cd139de98ba5bfee4e68fb853b5484",
    "safe": "0x092CC1854399ADc38Dad4f846E369C40D0a40307",
    "to": "0x8e6A5aDb2B88257A3DAc7A76A7B4EcaCdA090b66",
    "value": "1000123",
    "data": "",
    "operation": "0",
    "txGas": "21000",
    "dataGas": "0",
    "gasPrice": "99123001",
    "gasToken": "0x1000000000000000000000000000000000000001",
    "nonce": "3"
},
{
    "type": "requestConfirmation",
    "hash": "0x73131ee03daae3e0cbd1bce81ae50291562539ee5c806506eebd0aaa33d0fbe3",
    "safe": "0x092CC1854399ADc38Dad4f846E369C40D0a40307",
    "to": "0x8e6A5aDb2B88257A3DAc7A76A7B4EcaCdA090b66",
    "value": "1000123",
    "data": "0x561001057600080fd5b5060405161060a3803806106",
    "operation": "1",
    "txGas": "21000",
    "dataGas": "29943",
    "gasPrice": "99123001",
    "gasToken": "0x1001230000000000000000000000000000000001",
    "nonce": "12305734256"
}
]
"""
}

struct RawTransactionFixture {

    static let privateKey = MultisigWalletDomainModel.PrivateKey(data: Data(ethHex: "e331b6d69882b4cb4ea581d88e0b604039a3de5967688d3dcffdd2270c0fd109"))
    static let tx = EthRawTransaction(to: "0x0000000000000000000000000000000000000000",
                                      value: 0,
                                      data: "0x7f7465737432000000000000000000000000000000000000000000000000000000600057",
                                      gas: String(0x2710),
                                      gasPrice: String(0x09184e72a000),
                                      nonce: 0)
    static let anyChainHash = "0xf889808609184e72a00082271094000000000000000000000000000000000000000080a47f74657374320000000000000000000000000000000000000000000000000000006000571ca08a8bbf888cfa37bbf0bb965423625641fc956967b81d12e23709cead01446075a01ce999b56a8a88504be365442ea61239198e23d1fce7d00fcfc5cd3b44b7215f"
    static let rinkebyHash = "0xf889808609184e72a00082271094000000000000000000000000000000000000000080a47f74657374320000000000000000000000000000000000000000000000000000006000572ca0556affe36701467655f6000379805ab562e1a4699d8053607650eaae77c19700a03dd74edcf76263efe01c01423c1736d94d7d045a3cf3815e9c25b5c442b142b3"

}
// swiftlint:enable line_length

struct QRCode {

    let code: String
    let address: String

    static let validCode1 = QRCode(
        code: """
            {"expirationDate": "2018-05-09T14:18:55+00:00",
              "signature": {
                "v": 27,
                "r":"75119860711638973245538703589762310947594328712729260330312782656531560398776",
                "s":"51392727032514077370236468627319183981033698696331563950328005524752791633785"
              }
            }
            """,
        address: "0xeBECD3521491D9D2CAA5111D23B6B764238DD09f"
    )

    static let validCode2 = QRCode(
        code: """
            {"expirationDate" : "2018-05-17T13:47:00+00:00",
              "signature": {
                "v": 27,
                "r":"79425995431864040500581522255237765710685762616259654871112297909982135982384",
                "s":"1777326029228985739367131500591267170048497362640342741198949880105318675913"
              }
            }
            """,
        address: "0xeBECD3521491D9D2CAA5111D23B6B764238DD09f"
    )

    static let invalidCode1 = QRCode(
        code: """
        {"expirationDate": "2018-05-09T14:18:55+00:00",
          "signature": {
            "v": 27,
            "r":"75119860711638973245538703589762310947594328712729260330312782656531560398776"
          }
        }
        """,
        address: "0xeBECD3521491D9D2CAA5111D23B6B764238DD09f"
    )

}


class CustomWordsEthereumService: EthereumKitEthereumService {

    let words: [String]

    init(words: [String]) {
        self.words = words
    }

    override func createMnemonic() -> [String] {
        return words
    }

}

class MockEthereumService: EthereumService {

    var mnemonic = [String]()
    var seed = Data()
    var privateKey = Data()
    var publicKey = Data()
    var address = "address"

    func createMnemonic() -> [String] {
        return mnemonic
    }

    func createSeed(mnemonic: [String]) -> Data {
        return seed
    }

    func createHDPrivateKey(seed: Data, network: EIP155ChainId, derivedAt: Int) -> Data {
        return privateKey
    }

    func createPublicKey(privateKey: Data) -> Data {
        return publicKey
    }

    func createAddress(publicKey: Data) -> String {
        return address
    }

}
