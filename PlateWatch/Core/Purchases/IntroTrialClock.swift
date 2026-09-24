import Foundation

/// Thin wrapper around `UserEntitlement` install-trial bookkeeping. Kept as
/// a separate type so `PlateWatchApp.init` can stamp the first launch in one
/// line and so the rest of the portfolio's IntroTrialClock convention reads
/// the same way here.
///
/// Mirrors RouteOS's `IntroTrialClock` (see
/// `~/Developer/routeos/RouteOS/Core/Purchases/IntroTrialClock.swift`) but
/// delegates persistence to `UserEntitlement` so there's a single source of
/// truth for the trial state.
struct IntroTrialClock {
    static let trialDays: Int = UserEntitlement.trialDays

    private let entitlement: UserEntitlement

    init(entitlement: UserEntitlement = UserEntitlement()) {
        self.entitlement = entitlement
    }

    @discardableResult
    func recordInstallIfNeeded(now: Date = Date()) -> Date {
        entitlement.recordFirstLaunchIfNeeded(now: now)
    }

    var installAt: Date? { entitlement.firstLaunchAt }
    var consumed: Bool { entitlement.installTrialConsumed }

    func markConsumed() { entitlement.markInstallTrialConsumed() }

    func isWithinTrial(now: Date = Date()) -> Bool {
        entitlement.installTrialActive(now: now)
    }

    func daysRemaining(now: Date = Date()) -> Int {
        let n = entitlement.trialDaysRemaining(now: now)
        return n == .max ? Self.trialDays : n
    }

    #if DEBUG
    func debugReset() { entitlement.debugReset() }
    func debugExpire() { entitlement.debugExpireTrial() }
    #endif
}
