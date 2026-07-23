import Foundation
import StoreKit

// MARK: - Subscription Service Protocol

protocol SubscriptionServiceProtocol: Sendable {
    var currentTier: SubscriptionTier { get }
    var status: SubscriptionStatus { get }
    var products: [Product] { get }
    func loadProducts() async
    func purchase(_ product: Product) async throws -> Bool
    func restorePurchases() async throws
    func updateSubscriptionStatus() async
}

// MARK: - StoreKit 2 Implementation

@MainActor
@Observable
final class SubscriptionService: SubscriptionServiceProtocol {
    private(set) var currentTier: SubscriptionTier = .free
    private(set) var status: SubscriptionStatus = .none
    private(set) var products: [Product] = []
    private var updateTask: Task<Void, Never>?

    init() {
        updateTask = Task { await observeTransactionUpdates() }
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: PeakConstants.Products.all)
                .sorted { $0.price < $1.price }
            PeakLogger.subscription.info("Loaded \(self.products.count) products")
        } catch {
            PeakLogger.subscription.error("Product load failed: \(error.localizedDescription)")
        }
    }

    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            PeakHaptics.success()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await updateSubscriptionStatus()
    }

    func updateSubscriptionStatus() async {
        var foundActive = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            if transaction.revocationDate != nil {
                status = .revoked
                currentTier = .free
                continue
            }

            if let expiration = transaction.expirationDate, expiration < Date() {
                status = .expired
                currentTier = .free
                continue
            }

            foundActive = true
            status = .active
            currentTier = tierForProduct(transaction.productID)

            if let expiration = transaction.expirationDate {
                let graceWindow = expiration.addingTimeInterval(86400 * 16)
                if Date() > expiration && Date() < graceWindow {
                    status = .gracePeriod
                }
            }
        }

        if !foundActive && status != .revoked {
            status = .none
            currentTier = .free
        }
    }

    private func tierForProduct(_ productID: String) -> SubscriptionTier {
        switch productID {
        case PeakConstants.Products.proMonthly: return .pro
        case PeakConstants.Products.premiumMonthly, PeakConstants.Products.premiumYearly: return .premium
        default: return .free
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw PeakError.subscriptionFailed("Transaction verification failed")
        case .verified(let value): return value
        }
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            guard let transaction = try? checkVerified(result) else { continue }
            await transaction.finish()
            await updateSubscriptionStatus()
        }
    }

    func canUseFeature(_ feature: PremiumFeature, tier: SubscriptionTier) -> Bool {
        switch feature {
        case .unlimitedHabits: return tier != .free
        case .fullHistory: return tier != .free
        case .advancedInsights: return tier != .free
        case .aiCoach: return true // limited on free
        case .exportPDF: return tier != .free
        case .customHabits: return tier != .free
        }
    }
}

enum PremiumFeature {
    case unlimitedHabits
    case fullHistory
    case advancedInsights
    case aiCoach
    case exportPDF
    case customHabits
}