import XCTest
@testable import PlateWatch

@MainActor
final class PurchaseManagerTests: XCTestCase {

    /// PricingConfig is canonical — the product IDs must match the
    /// Configuration.storekit + ASC IAP records exactly.
    func testProductIDsMatchSpec() {
        XCTAssertEqual(PricingConfig.allProductIds, [
            "com.plateaware.app.monthly",
            "com.plateaware.app.yearly",
        ])
    }

    /// Six disclosure strings must be present + non-empty + verbatim. The
    /// forfeiture sentence is mandatory because the annual carries a trial.
    func testDisclosureStringsArePresent() {
        XCTAssertTrue(PricingConfig.Disclosures.payment.contains("Apple ID"))
        XCTAssertTrue(PricingConfig.Disclosures.autoRenew.contains("automatically renew"))
        XCTAssertTrue(PricingConfig.Disclosures.renewalCharge.contains("renewal"))
        XCTAssertTrue(PricingConfig.Disclosures.manage.contains("Account Settings"))
        XCTAssertTrue(PricingConfig.Disclosures.freeTrial.contains("7 days"))
        XCTAssertTrue(PricingConfig.Disclosures.trialForfeit.contains("forfeited"))
    }

    /// Fresh PurchaseManager starts in non-pro, non-purchasing state.
    func testInitialState() {
        let defaults = UserDefaults(suiteName: "test.pm.\(UUID().uuidString)")!
        let entitlement = UserEntitlement(defaults: defaults)
        let pm = PurchaseManager(entitlement: entitlement)
        XCTAssertFalse(pm.isPro)
        XCTAssertFalse(pm.isPurchasing)
        XCTAssertEqual(pm.products.count, 0)
        XCTAssertNil(pm.lastError)
    }

    /// `isPro` flips true the moment the install trial is active, even
    /// without StoreKit ever being reached.
    func testIsProTrueDuringInstallTrial() {
        let suite = "test.pm.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let entitlement = UserEntitlement(defaults: defaults)
        entitlement.recordFirstLaunchIfNeeded()
        let pm = PurchaseManager(entitlement: entitlement)
        XCTAssertTrue(pm.isPro)
        XCTAssertTrue(pm.isInIntroTrial)
        XCTAssertGreaterThan(pm.introTrialDaysRemaining, 0)
    }
}
