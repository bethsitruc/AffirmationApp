import Foundation
import OSLog
import StoreKit
import AffirmationShared

enum SupportPurchaseOutcome: Equatable, Sendable { case purchased, pending, cancelled }

@MainActor
protocol SupportPurchasing {
    func prices(for ids: [String]) async throws -> [String: String]
    func purchase(id: String) async throws -> SupportPurchaseOutcome
}

@MainActor
final class StoreKitSupportClient: SupportPurchasing {
    private var products: [String: Product] = [:]
    func prices(for ids: [String]) async throws -> [String: String] {
        let loaded = try await Product.products(for: ids)
        products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        return products.mapValues(\.displayPrice)
    }
    static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        try result.payloadValue
    }
    func purchase(id: String) async throws -> SupportPurchaseOutcome {
        guard let product = products[id] else { throw URLError(.resourceUnavailable) }
        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try Self.verified(verification)
            await transaction.finish()
            return .purchased
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: throw URLError(.unknown)
        }
    }
}

@MainActor
final class SupportPurchaseManager: ObservableObject {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "bethsitruc.AffirmationApp",
        category: "SupportPurchases"
    )

    struct SupportOption: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let fallbackPrice: String
        let iconName: String
        let accessibilityIdentifier: String
    }

    static let options = [
        SupportOption(
            id: "bethsitruc.AffirmationApp.support.small",
            title: "Support the developer",
            subtitle: "A small thank-you",
            fallbackPrice: "$0.99",
            iconName: "heart.fill",
            accessibilityIdentifier: "supportSmallButton"
        ),
        SupportOption(
            id: "bethsitruc.AffirmationApp.coffee",
            title: "Buy the developer a coffee",
            subtitle: "A little extra support",
            fallbackPrice: "$4.99",
            iconName: "cup.and.saucer.fill",
            accessibilityIdentifier: "supportCoffeeButton"
        ),
    ]

    @Published private(set) var products: [String: String] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var purchasingProductID: String?
    @Published var notice: String?

    private var productLoadDiagnostic: String?
    private let client: any SupportPurchasing

    init(client: (any SupportPurchasing)? = nil) {
        if let client { self.client = client }
        else if RuntimeEnvironment.isTesting { self.client = UnavailableSupportClient() }
        else { self.client = StoreKitSupportClient() }
    }

    var isPurchasing: Bool {
        purchasingProductID != nil
    }

    func displayPrice(for option: SupportOption) -> String {
        products[option.id] ?? option.fallbackPrice
    }

    func isPurchasing(_ option: SupportOption) -> Bool {
        purchasingProductID == option.id
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let requestedIDs = Self.options.map(\.id)
            products = try await client.prices(for: requestedIDs)
            productLoadDiagnostic = Self.productDiagnostic(
                requestedIDs: requestedIDs,
                returnedIDs: Array(products.keys)
            )
            Self.logger.info("\(self.productLoadDiagnostic ?? "StoreKit product lookup completed.", privacy: .public)")
        } catch {
            let nsError = error as NSError
            productLoadDiagnostic = "StoreKit lookup failed (\(nsError.domain) code \(nsError.code)): \(nsError.localizedDescription)"
            Self.logger.error("\(self.productLoadDiagnostic ?? "Unknown StoreKit lookup error.", privacy: .public)")
        }
    }

    func purchase(_ option: SupportOption) async {
        guard !isPurchasing else { return }
        purchasingProductID = option.id
        notice = nil
        defer { purchasingProductID = nil }
        if products[option.id] == nil {
            await loadProducts()
        }

        guard products[option.id] != nil else {
            notice = "Support purchases are temporarily unavailable. Please try again later."
            return
        }

        do {
            switch try await client.purchase(id: option.id) {
            case .purchased:
                notice = "Thank you for supporting Grounded!"
            case .pending:
                notice = "Your purchase is pending approval."
            case .cancelled:
                break
            }
        } catch {
            notice = "The purchase could not be completed. Please try again."
        }
    }

    private static func productDiagnostic(requestedIDs: [String], returnedIDs: [String]) -> String {
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown bundle"
        let missingIDs = Set(requestedIDs).subtracting(returnedIDs).sorted()

        guard !missingIDs.isEmpty else {
            return "StoreKit returned all \(returnedIDs.count) products for \(bundleID)."
        }

        return "StoreKit returned \(returnedIDs.count) of \(requestedIDs.count) products for \(bundleID). Missing: \(missingIDs.joined(separator: ", "))."
    }
}

@MainActor
private struct UnavailableSupportClient: SupportPurchasing {
    func prices(for ids: [String]) async throws -> [String: String] { [:] }
    func purchase(id: String) async throws -> SupportPurchaseOutcome { throw URLError(.resourceUnavailable) }
}
