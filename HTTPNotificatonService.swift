//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import Foundation
import MultisigWalletDomainModel
import Common
import MultisigWalletApplication

final public class HTTPNotificationService: NotificationDomainService {

    private let httpClient: JSONHTTPClient

    public init(url: URL, logger: Logger) {
        httpClient = JSONHTTPClient(url: url, logger: logger)
    }

    public func pair(pairingRequest: PairingRequest) throws {
        let response = try httpClient.execute(request: pairingRequest)
        let browserExtensionAddress = pairingRequest.temporaryAuthorization.extensionAddress!
        let deviceOwnerAddress = pairingRequest.deviceOwnerAddress!
        guard response.devicePair.contains(browserExtensionAddress) &&
            response.devicePair.contains(deviceOwnerAddress) else {
                throw NotificationDomainServiceError.validationFailed
        }
    }

    public func deletePair(request: DeletePairRequest) throws {
        try httpClient.execute(request: request)
    }

    public func auth(request: AuthRequest) throws {
        let response = try httpClient.execute(request: request)
        // check that we received the same owners that we sent
        let expectedItems: Set<AuthRequest.AuthResponseItem> = Set(request.deviceOwnerAddresses.map { address in
            AuthRequest.AuthResponseItem(owner: address,
                                         pushToken: request.pushToken,
                                         client: request.client,
                                         buildNumber: request.buildNumber,
                                         versionName: request.versionName,
                                         bundle: request.bundle)
        })
        let actualItems = Set(response)
        guard actualItems == expectedItems else {
            let message = "authV2: unexpected response. Check that signatures and other data are correct"
            let error = NSError(domain: "io.gnosis.safe",
                                code: -801,
                                userInfo: [NSLocalizedDescriptionKey: message,
                                           "expected": Array(expectedItems),
                                           "actual": response])
            ApplicationServiceRegistry.logger.error(message, error: error)
            throw NotificationDomainServiceError.validationFailed
        }
    }

    public func send(notificationRequest: SendNotificationRequest) throws {
        try httpClient.execute(request: notificationRequest)
    }

    public func safeCreatedMessage(at address: String) -> String {
        struct Message: Encodable {
            var type = "safeCreation"
            var safe: String
            init(_ safe: String) { self.safe = safe }
        }
        return String(data: try! JSONEncoder().encode(Message(address)), encoding: .utf8)!
    }

    public func requestConfirmationMessage(for transaction: Transaction, hash: Data) -> String {
        struct Message: Encodable {
            var type: String
            var hash: String
            var safe: String
            var to: String
            var value: String
            var data: String
            var operation: String
            var txGas: String
            var dataGas: String
            var operationalGas: String
            var gasPrice: String
            var gasToken: String
            var nonce: String
        }
        let safe = DomainRegistry.encryptionService.address(from: transaction.sender!.value)!
        let to = DomainRegistry.encryptionService.address(from: transaction.ethTo.value)!
        let message = Message(type: "requestConfirmation",
                              hash: hash.toHexString().addHexPrefix(),
                              safe: safe.value,
                              to: to.value,
                              value: String(transaction.ethValue),
                              data: transaction.ethData,
                              operation: String(transaction.operation!.rawValue),
                              txGas: String(transaction.feeEstimate!.gas),
                              dataGas: String(transaction.feeEstimate!.dataGas),
                              operationalGas: String(transaction.feeEstimate!.operationalGas),
                              gasPrice: String(transaction.feeEstimate!.gasPrice.amount),
                              gasToken: transaction.feeEstimate!.gasPrice.token.address.value,
                              nonce: transaction.nonce!)
        return String(data: try! JSONEncoder().encode(message), encoding: .utf8)!
    }

    public func transactionSentMessage(for transaction: Transaction) -> String {
        let safe = DomainRegistry.encryptionService.address(from: transaction.sender!.value)!
        let to = DomainRegistry.encryptionService.address(from: transaction.ethTo.value)!
        let message = TransactionSentMessage(to: to,
                                             from: safe,
                                             hash: transaction.hash!,
                                             transactionHash: transaction.transactionHash!)
        return message.stringValue
    }

}

extension PairingRequest: JSONRequest {

    public var httpMethod: String { return "POST" }
    public var urlPath: String { return "/api/v1/pairing/" }
    public typealias ResponseType = DevicePair

    public struct DevicePair: Decodable {
        let devicePair: [String]
    }

}

extension DeletePairRequest: JSONRequest {

    public var httpMethod: String { return "DELETE" }
    public var urlPath: String { return "/api/v1/pairing/" }
    public typealias ResponseType = EmptyResponse

    public struct EmptyResponse: Decodable {}

}

extension SendNotificationRequest: JSONRequest {

    public var httpMethod: String { return "POST" }
    public var urlPath: String { return "/api/v1/notifications/" }
    public typealias ResponseType = EmptyResponse

}

extension AuthRequest: JSONRequest {

    public var httpMethod: String { return "POST" }
    public var urlPath: String { return "/api/v2/auth/" }
    public typealias ResponseType = [AuthResponseItem]

    public struct AuthResponseItem: Hashable, Equatable, Decodable {
        let owner: String
        let pushToken: String
        let client: String
        let buildNumber: Int
        let versionName: String
        let bundle: String
    }

}
