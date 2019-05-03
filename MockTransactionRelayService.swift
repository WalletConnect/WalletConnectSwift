//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import Foundation
import MultisigWalletDomainModel
import Common
import CommonTestSupport

public class MockTransactionRelayService: TransactionRelayDomainService {

    public let averageDelay: Double
    public let maxDeviation: Double

    public var shouldThrowNetworkError = false
    public var shouldThrow = false

    private var randomizedNetworkResponseDelay: Double {
        return Timer.random(average: averageDelay, maxDeviation: maxDeviation)
    }

    public init(averageDelay: Double, maxDeviation: Double) {
        self.averageDelay = averageDelay
        self.maxDeviation = fabs(maxDeviation)
    }

    public var createSafeCreationTransaction_input: SafeCreationTransactionRequest?

    public func createSafeCreationTransaction(request: SafeCreationTransactionRequest)
        throws -> SafeCreationTransactionRequest.Response {
            createSafeCreationTransaction_input = request
            Timer.wait(randomizedNetworkResponseDelay)
            // Please do not change data here. Or you will need to update StubEncryptionService to fix related UI tests.
            return .init(signature: .init(r: "222", s: request.s, v: "27"),
                         tx: .init(from: "", value: 0, data: "0x0001", gas: "10", gasPrice: "100", nonce: 0),
                         safe: "0x8c89eb758AF5Ee056Bc251328105F8893B057A05",
                         payment: "100")
    }

    public var startSafeCreation_input: Address?

    public func startSafeCreation(address: Address) throws {
        try throwIfNeeded()
        startSafeCreation_input = address
        Timer.wait(randomizedNetworkResponseDelay)
    }

    public func safeCreationTransactionHash(address: Address) throws -> TransactionHash? {
        try throwIfNeeded()
        Timer.wait(randomizedNetworkResponseDelay)
        return TransactionHash("0x3b9307c1473e915d04292a0f5b0f425eaf527f53852357e2c649b8c447e3246a")
    }

    public func gasPrice() throws -> SafeGasPriceResponse {
        try throwIfNeeded()
        Timer.wait(randomizedNetworkResponseDelay)
        return SafeGasPriceResponse(safeLow: "0", standard: "0", fast: "0", fastest: "0", lowest: "0")
    }

    public var submitTransaction_input: SubmitTransactionRequest?
    public var submitTransaction_output = SubmitTransactionRequest.Response(transactionHash: "")

    public func submitTransaction(request: SubmitTransactionRequest) throws -> SubmitTransactionRequest.Response {
        try throwIfNeeded()
        submitTransaction_input = request
        return submitTransaction_output
    }

    public var estimateTransaction_input: EstimateTransactionRequest?
    public var estimateTransaction_output: EstimateTransactionRequest.Response =
        .init(safeTxGas: 100,
              dataGas: 100,
              operationalGas: 100,
              gasPrice: 100,
              lastUsedNonce: 11,
              gasToken: "0x0000000000000000000000000000000000000000")

    public func estimateTransaction(request: EstimateTransactionRequest) throws -> EstimateTransactionRequest.Response {
        try throwIfNeeded()
        estimateTransaction_input = request
        return estimateTransaction_output
    }

    private func throwIfNeeded() throws {
        if shouldThrowNetworkError {
            throw JSONHTTPClient.Error.networkRequestFailed(URLRequest(url: URL(string: "http://test.url")!), nil, nil)
        }
        if shouldThrow { throw TestError.error }
    }

}
