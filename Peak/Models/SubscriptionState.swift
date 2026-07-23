import Foundation
import SwiftData

// MARK: - Cached Subscription State

@Model
final class SubscriptionStateRecord {
    var id: UUID
    var tier: String // SubscriptionTier raw value
    var status: String // SubscriptionStatus raw value
    var productID: String?
    var expirationDate: Date?
    var isInGracePeriod: Bool
    var isInBillingRetry: Bool
    var lastVerified: Date

    init(tier: SubscriptionTier = .free, status: SubscriptionStatus = .none) {
        self.id = UUID()
        self.tier = tier.rawValue
        self.status = status.rawValue
        self.isInGracePeriod = false
        self.isInBillingRetry = false
        self.lastVerified = Date()
    }

    var subscriptionTier: SubscriptionTier {
        SubscriptionTier(rawValue: tier) ?? .free
    }

    var subscriptionStatus: SubscriptionStatus {
        SubscriptionStatus(rawValue: status) ?? .none
    }
}

enum SubscriptionTier: String, Codable, CaseIterable {
    case free
    case premium
    case pro

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        case .pro: return "Pro"
        }
    }

    var aiMessageLimit: Int {
        switch self {
        case .free: return PeakConstants.FreeTierLimits.maxAIMessagesPerMonth
        case .premium: return PeakConstants.PremiumLimits.maxAIMessagesPerMonth
        case .pro: return PeakConstants.ProLimits.maxAIMessagesPerMonth
        }
    }

    var maxHabits: Int {
        switch self {
        case .free: return PeakConstants.FreeTierLimits.maxHabits
        case .premium, .pro: return Int.max
        }
    }

    var historyDays: Int {
        switch self {
        case .free: return PeakConstants.FreeTierLimits.historyDays
        case .premium, .pro: return 365 * 5
        }
    }
}

enum SubscriptionStatus: String, Codable {
    case none
    case active
    case gracePeriod
    case expired
    case revoked
    case billingRetry
}