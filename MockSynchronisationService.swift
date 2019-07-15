//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import Foundation
import MultisigWalletDomainModel
import Common

public final class MockSynchronisationService: SynchronisationDomainService {

    public init() {}

    var didSyncWCSessions = false
    public func syncWalletConnectSessions() {
        didSyncWCSessions = true
    }

    public var didSync = false
    public func syncTokensAndAccountsOnce() {
        Timer.wait(0.2)
        didSync = true
    }

    public var didStart = false
    public func startSyncLoop() {
        didStart = true
    }

    public var didStop = false
    public func stopSyncLoop() {
        didStop = true
    }

}
