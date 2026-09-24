import XCTest
@testable import PlateWatch

/// Install-time trial bookkeeping — the canonical Stage 1 test set per the
/// Subscriptions playbook Rule 4 + the task spec's acceptance criteria.
///
/// Each test uses a private UserDefaults suite so concurrent tests don't
/// race against the shared store.
@MainActor
final class InstallTrialTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "test.platewatch.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
    }

    /// Recording first launch returns the stamp and stores it; calling again
    /// returns the same stamp.
    func testFirstLaunchStampIsIdempotent() {
        let e = UserEntitlement(defaults: defaults)
        XCTAssertNil(e.firstLaunchAt)
        let first = e.recordFirstLaunchIfNeeded()
        let second = e.recordFirstLaunchIfNeeded()
        XCTAssertEqual(first, second)
        XCTAssertEqual(e.firstLaunchAt, first)
    }

    /// Inside the trial window, install-trial is active and isEntitled is
    /// true even though isPremium is false.
    func testInstallTrialActiveWithinWindow() {
        let e = UserEntitlement(defaults: defaults)
        let now = Date()
        e.recordFirstLaunchIfNeeded(now: now)
        let day3 = now.addingTimeInterval(3 * 86400)
        XCTAssertFalse(e.isPremium)
        XCTAssertTrue(e.installTrialActive(now: day3))
        XCTAssertTrue(e.isEntitled(now: day3))
        XCTAssertEqual(e.trialDaysRemaining(now: day3), 4)
    }

    /// Past the trial window, install-trial flips off and isEntitled is false.
    func testInstallTrialInactiveAfterWindow() {
        let e = UserEntitlement(defaults: defaults)
        let now = Date()
        e.recordFirstLaunchIfNeeded(now: now)
        let day10 = now.addingTimeInterval(10 * 86400)
        XCTAssertFalse(e.installTrialActive(now: day10))
        XCTAssertFalse(e.isEntitled(now: day10))
        XCTAssertEqual(e.trialDaysRemaining(now: day10), 0)
    }

    /// During the trial, every Pro action should be allowed by the gate.
    /// Mirrors RoadBinder's `testInstallTrialBeatsQuota` — premium features
    /// are unlocked during trial without a purchase.
    func testGateGrantsProDuringTrial() {
        let e = UserEntitlement(defaults: defaults)
        let now = Date()
        e.recordFirstLaunchIfNeeded(now: now)
        let day2 = now.addingTimeInterval(2 * 86400)
        let usage = GatedUsage(searchesToday: 100) // way over free quota
        XCTAssertEqual(EntitlementGate.evaluate(.runSearch,            entitlement: e, usage: usage, now: day2), .allowed)
        XCTAssertEqual(EntitlementGate.evaluate(.runRouteScan,         entitlement: e, usage: usage, now: day2), .allowed)
        XCTAssertEqual(EntitlementGate.evaluate(.enableProximityAlerts, entitlement: e, usage: usage, now: day2), .allowed)
        XCTAssertEqual(EntitlementGate.evaluate(.downloadOfflinePack,  entitlement: e, usage: usage, now: day2), .allowed)
        XCTAssertEqual(EntitlementGate.evaluate(.saveRoute,            entitlement: e, usage: usage, now: day2), .allowed)
        XCTAssertEqual(EntitlementGate.evaluate(.viewReportHistory,    entitlement: e, usage: usage, now: day2), .allowed)
        XCTAssertEqual(EntitlementGate.evaluate(.viewDensityScore,     entitlement: e, usage: usage, now: day2), .allowed)
    }

    /// Premium short-circuits every gate to `.allowed`, even years past install.
    func testPremiumAlwaysAllowed() {
        let e = UserEntitlement(defaults: defaults)
        let now = Date()
        e.recordFirstLaunchIfNeeded(now: now.addingTimeInterval(-365 * 86400))
        e.applyPaidEntitlement(productId: PricingConfig.yearlyProductId,
                               expiresAt: now.addingTimeInterval(180 * 86400))
        XCTAssertTrue(e.isPremium)
        XCTAssertTrue(e.isEntitled())
        XCTAssertEqual(EntitlementGate.evaluate(.runRouteScan,
                                                entitlement: e,
                                                usage: GatedUsage(searchesToday: 9999)), .allowed)
    }

    /// Once a paid subscription lands, the install trial flips to consumed
    /// so that a refund + clock backdate can't reopen the trial window.
    func testPaidEntitlementConsumesInstallTrial() {
        let e = UserEntitlement(defaults: defaults)
        e.recordFirstLaunchIfNeeded()
        XCTAssertFalse(e.installTrialConsumed)
        e.applyPaidEntitlement(productId: PricingConfig.monthlyProductId, expiresAt: nil)
        XCTAssertTrue(e.installTrialConsumed)
        // Revoke premium (e.g. sub expired) — trial does NOT come back.
        e.revokePaidEntitlement()
        XCTAssertFalse(e.isPremium)
        XCTAssertFalse(e.installTrialActive())
        XCTAssertFalse(e.isEntitled())
    }

    /// Free-tier gate behavior post-trial: search has a daily quota,
    /// premium features return .premiumOnly.
    func testFreeTierBehaviorAfterTrial() {
        let e = UserEntitlement(defaults: defaults)
        let now = Date()
        e.recordFirstLaunchIfNeeded(now: now)
        let day9 = now.addingTimeInterval(9 * 86400)

        let underQuota = GatedUsage(searchesToday: 3)
        let atQuota = GatedUsage(searchesToday: EntitlementGate.freeDailySearchQuota)

        XCTAssertEqual(EntitlementGate.evaluate(.runSearch, entitlement: e, usage: underQuota, now: day9), .freeAllowed)
        if case .quotaExhausted = EntitlementGate.evaluate(.runSearch, entitlement: e, usage: atQuota, now: day9) {
            // pass
        } else {
            XCTFail("expected quotaExhausted at quota")
        }
        if case .premiumOnly = EntitlementGate.evaluate(.runRouteScan, entitlement: e, usage: underQuota, now: day9) {
            // pass
        } else {
            XCTFail("expected premiumOnly for route scan post-trial")
        }
    }

    /// Data preservation: resetting paid entitlement doesn't wipe the
    /// firstLaunchAt stamp. (Future-proof — we never want a refund to
    /// silently start a new trial window.)
    func testDataPreservedAfterTrialExpiry() {
        let e = UserEntitlement(defaults: defaults)
        let installed = Date().addingTimeInterval(-100 * 86400)
        e.recordFirstLaunchIfNeeded(now: installed)
        e.applyPaidEntitlement(productId: PricingConfig.monthlyProductId, expiresAt: nil)
        e.revokePaidEntitlement()
        XCTAssertNotNil(e.firstLaunchAt)
        XCTAssertEqual(e.firstLaunchAt?.timeIntervalSince1970 ?? 0,
                       installed.timeIntervalSince1970, accuracy: 1.0)
        // installTrialConsumed should stay true.
        XCTAssertTrue(e.installTrialConsumed)
    }

    /// Clock-rollback protection: if the user backdates their device clock
    /// after the trial expires, the high-water mark should keep the trial
    /// from re-opening.
    func testClockRollbackCannotReopenTrial() {
        let e = UserEntitlement(defaults: defaults)
        let start = Date()
        e.recordFirstLaunchIfNeeded(now: start)
        // Advance the high-water clock past the trial window.
        _ = e.isEntitled(now: start.addingTimeInterval(10 * 86400))
        // Now roll the wall clock back to day 1.
        let rolledBack = start.addingTimeInterval(1 * 86400)
        XCTAssertFalse(e.installTrialActive(now: rolledBack))
    }
}
