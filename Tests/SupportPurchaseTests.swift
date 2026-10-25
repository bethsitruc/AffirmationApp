import Foundation
import StoreKit
import Testing
@testable import AffirmationApp

extension GroundedTests {
    @MainActor
    @Suite("Support purchase outcomes")
    struct SupportPurchaseTests {
        @Test("The production StoreKit adapter rejects unverified payloads")
        func verificationBoundary() throws {
            #expect(try StoreKitSupportClient.verified(VerificationResult.verified(42)) == 42)
            #expect(throws: VerificationResult<Int>.VerificationError.self) {
                try StoreKitSupportClient.verified(VerificationResult.unverified(42, .invalidSignature))
            }
        }

        @Test("Localized prices are loaded and successful purchases clear busy state")
        func success() async throws {
            let client = FakePurchases()
            let manager = SupportPurchaseManager(client: client)
            let option = SupportPurchaseManager.options[0]
            await manager.loadProducts()
            #expect(manager.displayPrice(for: option) == "€1,09")
            await manager.purchase(option)
            #expect(client.purchased == [option.id])
            #expect(manager.notice == "Thank you for supporting Grounded!")
            #expect(!manager.isLoading && !manager.isPurchasing)
        }
        @Test("Pending and cancelled transactions never claim success", arguments: [SupportPurchaseOutcome.pending, .cancelled])
        func nonSuccess(outcome: SupportPurchaseOutcome) async {
            let client = FakePurchases(); client.outcome = outcome
            let manager = SupportPurchaseManager(client: client)
            await manager.purchase(SupportPurchaseManager.options[0])
            #expect(manager.notice == (outcome == .pending ? "Your purchase is pending approval." : nil))
            #expect(!manager.isPurchasing)
        }
        @Test("Missing products and lookup errors do not attempt a purchase", arguments: [false, true])
        func unavailable(throwsError: Bool) async {
            let client = FakePurchases(); client.missing = true; client.failLookup = throwsError
            let manager = SupportPurchaseManager(client: client)
            await manager.purchase(SupportPurchaseManager.options[0])
            #expect(client.purchased.isEmpty)
            #expect(manager.notice?.contains("temporarily unavailable") == true)
            #expect(!manager.isLoading && !manager.isPurchasing)
        }
        @Test("Cancelling a later purchase does not retain a previous success notice")
        func cancellationClearsStaleNotice() async {
            let client = FakePurchases()
            let manager = SupportPurchaseManager(client: client)
            await manager.purchase(SupportPurchaseManager.options[0])
            client.outcome = .cancelled
            await manager.purchase(SupportPurchaseManager.options[1])
            #expect(manager.notice == nil)
        }

        @Test("Repeated taps during lookup or an in-flight transaction do not start duplicate purchases")
        func overlappingPurchases() async {
            let client = FakePurchases(); client.holdLookup = true
            let manager = SupportPurchaseManager(client: client)
            let first = Task { await manager.purchase(SupportPurchaseManager.options[0]) }
            for _ in 0..<100 where client.lookupContinuation == nil { await Task.yield() }
            #expect(client.lookupContinuation != nil)
            #expect(manager.isPurchasing)
            await manager.purchase(SupportPurchaseManager.options[1])
            #expect(manager.notice == nil)
            client.holdLookup = false
            client.lookupContinuation?.resume(returning: [SupportPurchaseManager.options[0].id: "€1,09"])
            await first.value
            #expect(client.purchased == [SupportPurchaseManager.options[0].id])

            client.purchased = []
            client.holdPurchase = true
            let inFlight = Task { await manager.purchase(SupportPurchaseManager.options[0]) }
            for _ in 0..<100 where client.purchaseContinuation == nil { await Task.yield() }
            #expect(client.purchaseContinuation != nil)
            await manager.purchase(SupportPurchaseManager.options[1])
            #expect(client.purchased == [SupportPurchaseManager.options[0].id])
            #expect(manager.isPurchasing)
            client.purchaseContinuation?.resume(returning: .purchased)
            await inFlight.value
        }

        @Test("Failed or unverified purchase reports failure and permits a retry")
        func failureThenRetry() async {
            let client = FakePurchases(); client.failPurchase = true
            let manager = SupportPurchaseManager(client: client)
            await manager.purchase(SupportPurchaseManager.options[0])
            #expect(manager.notice?.contains("could not be completed") == true)
            #expect(!manager.isPurchasing)
            client.failPurchase = false
            await manager.purchase(SupportPurchaseManager.options[0])
            #expect(manager.notice?.contains("Thank you") == true)
        }
    }
}

@MainActor
private final class FakePurchases: SupportPurchasing {
    var outcome = SupportPurchaseOutcome.purchased
    var purchased: [String] = []
    var missing = false
    var holdLookup = false
    var holdPurchase = false
    var purchaseContinuation: CheckedContinuation<SupportPurchaseOutcome, Never>?
    var lookupContinuation: CheckedContinuation<[String: String], Never>?
    var failLookup = false
    var failPurchase = false
    func prices(for ids: [String]) async throws -> [String: String] {
        if holdLookup { return await withCheckedContinuation { lookupContinuation = $0 } }
        if failLookup { throw URLError(.notConnectedToInternet) }
        return missing ? [:] : Dictionary(uniqueKeysWithValues: ids.map { ($0, "€1,09") })
    }
    func purchase(id: String) async throws -> SupportPurchaseOutcome {
        purchased.append(id)
        if holdPurchase {
            holdPurchase = false
            return await withCheckedContinuation { purchaseContinuation = $0 }
        }
        if failPurchase { throw URLError(.cannotParseResponse) }
        return outcome
    }
}
