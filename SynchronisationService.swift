//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import Foundation
import UIKit
import MultisigWalletDomainModel
import MultisigWalletApplication

public class SynchronisationService: SynchronisationDomainService {

    private let merger: TokenListMerger
    private let syncInterval: TimeInterval
    private var syncLoopRepeater: Repeater?

    private var hasAccessToFilesystem: Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            var status: Bool = false
            DispatchQueue.main.sync {
                status = UIApplication.shared.isProtectedDataAvailable
            }
            return status
        #endif
    }

    public init(syncInterval: TimeInterval = 10, merger: TokenListMerger = TokenListMerger()) {
        self.merger = merger
        self.syncInterval = syncInterval
    }

    /// Synchronise token list and account balances with info from remote services.
    /// Should be called from a background thread.
    public func syncOnce() {
        precondition(!Thread.isMainThread)
        syncTokenList()
        let hasSyncInProgress = syncLoopRepeater != nil && syncLoopRepeater!.isRunning
        if !hasSyncInProgress {
            syncAccounts()
        }
    }

    /// Synchronizes token list from the server with the local data. Errors are logged but not thrown.
    private func syncTokenList() {
        guard hasAccessToFilesystem else { return }
        do {
            let tokenList = try DomainRegistry.tokenListService.items()
            merger.mergeStoredTokenItems(with: tokenList)
        } catch {
            // GH-681 Skip logging of the "Request timed out" error, because sync will happen again
            if error.domain == NSURLErrorDomain && error.code == -1_001 {
                return
            }
            ApplicationServiceRegistry.logger.error("Failed to sync token list", error: error)
        }
    }

    /// Synchronizes account balances for tokens that were enabled. Errors are logged but not thrown.
    private func syncAccounts() {
        guard hasAccessToFilesystem else { return }
        do {
            try DomainRegistry.accountUpdateService.updateAccountsBalances()
        } catch {
            // GH-680 Skip logging of the posix error (something wrong with the system, nothing we can do)
            if error.domain == NSPOSIXErrorDomain && error.code == 53 {
                return
            }
            ApplicationServiceRegistry.logger.error("Failed to sync account balances", error: error)
        }
    }

    /// Synchronizes statuses of pending transactions. Errors are logged but not thrown.
    private func syncTransactions() {
        guard hasAccessToFilesystem else { return }
        do {
            try DomainRegistry.transactionService.updatePendingTransactions()
        } catch {
            ApplicationServiceRegistry.logger.error("Failed to sync pending transactions", error: error)
        }
    }

    /// Watches for transactions to process and then executes appropriate actions. Errors are logged but not thrown.
    private func postProcessTransactions() {
        do {
            guard hasAccessToFilesystem else { return }
            try DomainRegistry.replaceExtensionService.postProcessTransactions()

            guard hasAccessToFilesystem else { return }
            try DomainRegistry.connectExtensionService.postProcessTransactions()

            guard hasAccessToFilesystem else { return }
            try DomainRegistry.disconnectExtensionService.postProcessTransactions()
        } catch {
            ApplicationServiceRegistry.logger.error("Failed to post process transactions", error: error)
        }
    }

    /// Starts synchronisation loop on a background thread. Every `syncInterval` seconds the loop executes
    /// and updates pending transactions, account balances, and post processing actions.
    /// If inbetween of these udpates the synchronisation is stopped, then all further actions are skipped.
    public func startSyncLoop() {
        guard syncLoopRepeater == nil else { return }
        DispatchQueue.global.async {
            // repeat syncronization loop every `syncInterval`
            self.syncLoopRepeater = Repeater(delay: self.syncInterval) { [unowned self] repeater in
                if repeater.isStopped { return }
                self.syncTransactions()
                if repeater.isStopped { return }
                self.syncAccounts()
                if repeater.isStopped { return }
                self.postProcessTransactions()
            }
            // blocks current thread until the repeater is not stopped.
            try! self.syncLoopRepeater!.start()
        }
    }

    /// Stops a synchronisation loop, if it is running in background.
    public func stopSyncLoop() {
        if let repeater = syncLoopRepeater {
            repeater.stop()
            syncLoopRepeater = nil
        }
    }

    public static func syncProcessedTransactions() throws {
        try DomainRegistry.transactionService.updateTimestampsOfProcessedTransactions()
    }

}

fileprivate extension Error {

    var domain: String {
        return (self as NSError).domain
    }

    var code: Int {
        return (self as NSError).code
    }

}
