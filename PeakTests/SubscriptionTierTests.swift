import XCTest
@testable import Peak

final class SubscriptionTierTests: XCTestCase {
    func testFreeTierLimits() {
        XCTAssertEqual(SubscriptionTier.free.maxHabits, 3)
        XCTAssertEqual(SubscriptionTier.free.aiMessageLimit, 10)
        XCTAssertEqual(SubscriptionTier.free.historyDays, 14)
    }

    func testPremiumTierLimits() {
        XCTAssertEqual(SubscriptionTier.premium.aiMessageLimit, 500)
        XCTAssertEqual(SubscriptionTier.premium.maxHabits, Int.max)
    }

    func testProTierLimits() {
        XCTAssertEqual(SubscriptionTier.pro.aiMessageLimit, 2000)
    }
}