import Foundation
import StoreKitTest
import Testing
@testable import AffirmationApp

extension GroundedTests {
    @MainActor
    @Suite("Local StoreKit integration")
    struct StoreKitIntegrationTests {
        @Test("StoreKit product lookup, verified purchase, and pending approval use local transactions",
              .enabled(if: ProcessInfo.processInfo.environment["GROUNDED_STOREKIT_INTEGRATION"] == "1"))
        func localTransactions() async throws {
            let bundle = Bundle(for: StoreKitResourceMarker.self)
            let url = try #require(bundle.url(forResource: "SupportPurchases", withExtension: "storekit"))
            let session = try SKTestSession(contentsOf: url)
            session.disableDialogs = true
            try #require(session.disableDialogs, "StoreKit testing service did not initialize; do not attempt a transaction")
            session.clearTransactions()
            defer { session.clearTransactions(); session.resetToDefaultState() }
            let manager = SupportPurchaseManager(client: StoreKitSupportClient())
            let option = SupportPurchaseManager.options[0]
            await manager.loadProducts()
            #expect(manager.products[option.id] != nil)
            await manager.purchase(option)
            #expect(manager.notice == "Thank you for supporting Grounded!")
            #expect(session.allTransactions().count == 1)
            session.askToBuyEnabled = true
            manager.notice = nil
            await manager.purchase(SupportPurchaseManager.options[1])
            #expect(manager.notice == "Your purchase is pending approval.")
            #expect(!manager.isPurchasing)
        }
    }
}
private final class StoreKitResourceMarker: NSObject {}
