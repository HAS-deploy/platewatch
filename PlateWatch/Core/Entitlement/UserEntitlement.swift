import Foundation

/// PlateWatch entitlement state. Mirrors RoadBinder's `UserEntitlement` /
/// `EntitlementGate` pattern (see `~/Developer/roadbinder/RoadBinder/Models/
/// UserEntitlement.swift`) but backed by UserDefaults instead of SwiftData —
/// PlateWatch doesn't need a persistent model graph at this layer, and the
/// task spec explicitly calls out `platewatch.firstLaunchAt` as the
/// UserDefaults key.
///
/// Three reads everything else in the app uses:
///   - `isPremium`  → paid sub active
///   - `installTrialActive` → first launch was less than `trialDays` ago
///   - `isEntitled` → either of the above
///
/// Every gate / limit reads `isEntitled`, NEVER `isPremium`. That's the rule
/// from the install-trial playbook — during trial, free users see Pro
/// features so they form the habit.
struct UserEntitlement {
    static let trialDays: Int = 7

    // UserDefaults keys — namespaced under "platewatch." per spec.
    private static let kFirstLaunchAt          = "platewatch.firstLaunchAt"
    private static let kFirstLaunchHighWater   = "platewatch.firstLaunchAt.highWater"
    private static let kInstallTrialConsumed   = "platewatch.installTrial.consumed"
    private static let kIsPremium              = "platewatch.isPremium"
    private static let kSubscriptionProductId  = "platewatch.subscription.productId"
    private static let kSubscriptionExpiresAt  = "platewatch.subscription.expiresAt"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - First-launch stamp

    /// Records the current time as `firstLaunchAt` if no value is set yet.
    /// Returns the (possibly pre-existing) stamp. Idempotent: subsequent
    /// calls never overwrite the original. Called once per app launch from
    /// `PlateWatchApp.init` so the trial clock starts the moment the user
    /// first opens the app.
    @discardableResult
    func recordFirstLaunchIfNeeded(now: Date = Date()) -> Date {
        bumpHighWater(now)
        if let existing = defaults.object(forKey: Self.kFirstLaunchAt) as? Date {
            return existing
        }
        defaults.set(now, forKey: Self.kFirstLaunchAt)
        return now
    }

    var firstLaunchAt: Date? {
        defaults.object(forKey: Self.kFirstLaunchAt) as? Date
    }

    // MARK: - Premium

    /// `true` when the user has a paid sub OR the build is running under
    /// TestFlight / a StoreKit sandbox environment. The sandbox short-circuit
    /// lets internal beta testers exercise every premium feature without
    /// going through a purchase flow. Production App Store receipts end in
    /// `"receipt"` and bypass this branch, so paying behavior is unchanged
    /// for real users.
    var isPremium: Bool {
        get {
            if Self.isSandboxRuntime { return true }
            return defaults.bool(forKey: Self.kIsPremium)
        }
        nonmutating set { defaults.set(newValue, forKey: Self.kIsPremium) }
    }

    /// Returns `true` only when the running build's App Store receipt is a
    /// sandbox receipt — TestFlight + Apple's sandbox tester flow + simulator
    /// builds that load a `Configuration.storekit`. Production App Store
    /// downloads have a receipt URL ending in `"receipt"`, not
    /// `"sandboxReceipt"`, so this is `false` for paying customers.
    private static var isSandboxRuntime: Bool {
        Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
    }

    var subscriptionProductId: String? {
        get { defaults.string(forKey: Self.kSubscriptionProductId) }
        nonmutating set { defaults.set(newValue, forKey: Self.kSubscriptionProductId) }
    }

    var subscriptionExpiresAt: Date? {
        get { defaults.object(forKey: Self.kSubscriptionExpiresAt) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Self.kSubscriptionExpiresAt) }
    }

    var installTrialConsumed: Bool {
        get { defaults.bool(forKey: Self.kInstallTrialConsumed) }
        nonmutating set { defaults.set(newValue, forKey: Self.kInstallTrialConsumed) }
    }

    // MARK: - Trial math

    /// Monotonic effective time — clamps below by the highest wall-clock time
    /// we've ever observed so rolling the device clock backward after the
    /// trial expires can't reopen the window.
    private func effectiveNow(_ now: Date) -> Date {
        let stored = (defaults.object(forKey: Self.kFirstLaunchHighWater) as? Date) ?? .distantPast
        let effective = max(stored, now)
        if effective > stored {
            defaults.set(effective, forKey: Self.kFirstLaunchHighWater)
        }
        return effective
    }

    private func bumpHighWater(_ now: Date) {
        let stored = (defaults.object(forKey: Self.kFirstLaunchHighWater) as? Date) ?? .distantPast
        if now > stored {
            defaults.set(now, forKey: Self.kFirstLaunchHighWater)
        }
    }

    /// Whole days remaining in the install trial. Returns 0 once consumed
    /// or expired. Premium short-circuits to `.max`.
    func trialDaysRemaining(now: Date = Date()) -> Int {
        if isPremium { return .max }
        if installTrialConsumed { return 0 }
        guard let start = firstLaunchAt else { return Self.trialDays }
        let effective = effectiveNow(now)
        guard effective >= start else { return Self.trialDays }
        let elapsedSeconds = effective.timeIntervalSince(start)
        let remainingSeconds = TimeInterval(Self.trialDays) * 86400 - elapsedSeconds
        return max(0, Int(ceil(remainingSeconds / 86400)))
    }

    /// True iff first-launch was set and is less than `trialDays` days ago.
    /// Independent of `isPremium` — `isEntitled` ORs them together.
    func installTrialActive(now: Date = Date()) -> Bool {
        if installTrialConsumed { return false }
        guard let start = firstLaunchAt else { return false }
        let effective = effectiveNow(now)
        guard effective >= start else { return false }
        return effective.timeIntervalSince(start) < TimeInterval(Self.trialDays) * 86400
    }

    /// THE read every gate / limit uses. Reads `isPremium` OR
    /// `installTrialActive`. Never read `isPremium` directly from a gate.
    func isEntitled(now: Date = Date()) -> Bool {
        if isPremium { return true }
        return installTrialActive(now: now)
    }

    // MARK: - Mutating helpers (called by PurchaseManager)

    /// Mark the install trial as consumed — called when a paid sub lands so
    /// a refund doesn't re-open the window.
    func markInstallTrialConsumed() {
        defaults.set(true, forKey: Self.kInstallTrialConsumed)
    }

    /// Apply a verified StoreKit entitlement.
    func applyPaidEntitlement(productId: String, expiresAt: Date?) {
        defaults.set(true, forKey: Self.kIsPremium)
        defaults.set(productId, forKey: Self.kSubscriptionProductId)
        if let expiresAt {
            defaults.set(expiresAt, forKey: Self.kSubscriptionExpiresAt)
        } else {
            defaults.removeObject(forKey: Self.kSubscriptionExpiresAt)
        }
        if !installTrialConsumed {
            defaults.set(true, forKey: Self.kInstallTrialConsumed)
        }
    }

    /// Revoke premium — called when StoreKit's currentEntitlements no longer
    /// contains an active sub (sub expired / refunded).
    func revokePaidEntitlement() {
        defaults.set(false, forKey: Self.kIsPremium)
        defaults.removeObject(forKey: Self.kSubscriptionProductId)
        defaults.removeObject(forKey: Self.kSubscriptionExpiresAt)
    }

    /// Wipe all entitlement state — install-trial stamp, high-water, premium,
    /// subscription metadata. Used by Settings → Reset App Data (Release path)
    /// and by the install-trial tests' setUp. After this call, the next
    /// `recordFirstLaunchIfNeeded` restamps the trial clock as if the user
    /// just installed.
    func fullReset() {
        defaults.removeObject(forKey: Self.kFirstLaunchAt)
        defaults.removeObject(forKey: Self.kFirstLaunchHighWater)
        defaults.removeObject(forKey: Self.kInstallTrialConsumed)
        defaults.removeObject(forKey: Self.kIsPremium)
        defaults.removeObject(forKey: Self.kSubscriptionProductId)
        defaults.removeObject(forKey: Self.kSubscriptionExpiresAt)
    }

    #if DEBUG
    /// Test/debug alias — same body as `fullReset`. Kept for source-compat
    /// with existing test call sites.
    func debugReset() { fullReset() }

    /// Force the install trial to look expired by backdating firstLaunchAt.
    /// Useful for the Stage 4B simulator audit.
    func debugExpireTrial() {
        let backdated = Date().addingTimeInterval(-TimeInterval(Self.trialDays + 1) * 86400)
        defaults.set(backdated, forKey: Self.kFirstLaunchAt)
        defaults.set(backdated, forKey: Self.kFirstLaunchHighWater)
    }
    #endif
}
