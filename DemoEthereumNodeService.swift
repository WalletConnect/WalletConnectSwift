//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import Foundation
import MultisigWalletDomainModel
import Common
import BigInt

public class DemoEthereumNodeService: EthereumNodeDomainService {

    public let delay: TimeInterval

    public init(delay: TimeInterval = 5) {
        self.delay = delay
    }

    private var balanceUpdateCounter = 0

    public func eth_getBalance(account: Address) throws -> BigInt {
        Timer.wait(delay)
        if account.value == "0x8c89eb758AF5Ee056Bc251328105F8893B057A05" {
            let balance = BigInt(min(balanceUpdateCounter * 50, 100))
            balanceUpdateCounter += 1
            return balance
        } else {
            return 0
        }
    }

    private var receiptUpdateCounter = 0

    public func eth_getTransactionReceipt(transaction: TransactionHash) throws -> TransactionReceipt? {
        Timer.wait(delay)
        if receiptUpdateCounter == 3 {
            return TransactionReceipt(hash: transaction, status: .success, blockHash: "0x1")
        } else {
            receiptUpdateCounter += 1
            return nil
        }
    }

    public func eth_call(to: Address, data: Data) throws -> Data {
        return Data()
    }

    public func eth_getBlockByHash(hash: String) throws -> EthBlock? {
        return EthBlock(hash: "0x1", timestamp: Date())
    }

}
