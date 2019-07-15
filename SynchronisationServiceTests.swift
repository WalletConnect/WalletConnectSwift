//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import MultisigWalletImplementations
import MultisigWalletDomainModel
import CommonTestSupport

class SynchronisationServiceTests: XCTestCase {

    var syncService: SynchronisationService!
    let tokenListService = MockTokenListService()
    let accountService = MockAccountUpdateService()
    let tokenListItemRepository = InMemoryTokenListItemRepository()
    let portfolioRepository = InMemorySinglePortfolioRepository()
    let walletRepository = InMemoryWalletRepository()
    let publisher = MockEventPublisher()

    override func setUp() {
        super.setUp()
        DomainRegistry.put(service: tokenListService, for: TokenListDomainService.self)
        DomainRegistry.put(service: tokenListItemRepository, for: TokenListItemRepository.self)
        DomainRegistry.put(service: portfolioRepository, for: SinglePortfolioRepository.self)
        DomainRegistry.put(service: walletRepository, for: WalletRepository.self)
        DomainRegistry.put(service: publisher, for: EventPublisher.self)
        DomainRegistry.put(service: accountService, for: AccountUpdateDomainService.self)
        syncService = SynchronisationService()
    }

    func test_whenSync_thenCallsTokenListService() {
        startSync()
        delay(0.25)
        assertTokenListSyncSuccess()
    }

    func test_whenSync_thenCallsAccountUpdateDomainService() {
        startSync()
        delay(0.25)
        assertAccountSyncSuccess()
    }

}

private extension SynchronisationServiceTests {

    func startSync(line: UInt = #line) {
        publisher.expectToPublish(TokenListMerged.self)
        publisher.expectToPublish(AccountsBalancesUpdated.self)
        XCTAssertFalse(tokenListService.didReturnItems, line: line)
        DispatchQueue.global().async {
            self.syncService.syncTokensAndAccountsOnce()
        }
    }

    private func assertTokenListSyncSuccess(line: UInt = #line) {
        XCTAssertTrue(tokenListService.didReturnItems, "Service returned no items", line: line)
        XCTAssertTrue(publisher.verify(), "Publisher not verified", line: line)
    }

    private func assertAccountSyncSuccess(line: UInt = #line) {
        XCTAssertTrue(accountService.didUpdateBalances, line: line)
    }

}
