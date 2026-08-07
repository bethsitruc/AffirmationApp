import Foundation
import StoreKit

@MainActor
final class SupportPurchaseManager: ObservableObject {
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

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var purchasingProductID: String?
    @Published var notice: String?

    var isPurchasing: Bool {
        purchasingProductID != nil
    }

    func displayPrice(for option: SupportOption) -> String {
        products[option.id]?.displayPrice ?? option.fallbackPrice
    }

    func isPurchasing(_ option: SupportOption) -> Bool {
        purchasingProductID == option.id
    }

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedProducts = try await Product.products(for: Self.options.map(\.id))
            products = Dictionary(uniqueKeysWithValues: loadedProducts.map { ($0.id, $0) })
        } catch {
            // Keep the support choices visible and retry when the customer taps one.
        }
    }

    func purchase(_ option: SupportOption) async {
        if products[option.id] == nil {
            await loadProducts()
        }

        guard let product = products[option.id] else {
            notice = "Support purchases are temporarily unavailable. Please try again later."
            return
        }

        purchasingProductID = option.id
        defer { purchasingProductID = nil }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                notice = "Thank you for supporting Grounded!"
            case .pending:
                notice = "Your purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                notice = "The purchase could not be completed. Please try again."
            }
        } catch {
            notice = "The purchase could not be completed. Please try again."
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw PurchaseError.failedVerification
        }
    }

    private enum PurchaseError: Error {
        case failedVerification
    }
}
