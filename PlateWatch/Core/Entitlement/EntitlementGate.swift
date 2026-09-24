import Foundation

/// Single decision point for whether a user can perform a Pro action in
/// PlateWatch. Three layers stack:
///   1. Premium → always allowed.
///   2. Inside install-time 7-day trial → allowed (full Pro).
///   3. Free tier → map + nearby pins + basic details + 5 searches/day, no
///      premium features.
///
/// Mirrors RoadBinder's `EntitlementGate` API. `isEntitled` is what every
/// caller actually reads — there is no path here that consults `isPremium`
/// directly.
@MainActor
enum EntitlementGate {
    static let freeDailySearchQuota = 5

    enum Decision: Equatable {
        case allowed                                            // premium OR inside trial
        case freeAllowed                                        // still under the free daily quota
        case quotaExhausted(kind: String, used: Int, quota: Int)
        case premiumOnly(feature: String)                       // no free allowance for this feature
    }

    /// Evaluate a gated action against the current entitlement + usage state.
    static func evaluate(_ action: GatedAction,
                         entitlement: UserEntitlement,
                         usage: GatedUsage,
                         now: Date = Date()) -> Decision {
        if entitlement.isEntitled(now: now) { return .allowed }
        switch action {
        case .runSearch:
            return usage.searchesToday < freeDailySearchQuota
                ? .freeAllowed
                : .quotaExhausted(kind: "searches",
                                  used: usage.searchesToday,
                                  quota: freeDailySearchQuota)
        case .runRouteScan:        return .premiumOnly(feature: action.rawValue)
        case .enableProximityAlerts: return .premiumOnly(feature: action.rawValue)
        case .downloadOfflinePack: return .premiumOnly(feature: action.rawValue)
        case .saveRoute:           return .premiumOnly(feature: action.rawValue)
        case .viewReportHistory:   return .premiumOnly(feature: action.rawValue)
        case .viewDensityScore:    return .premiumOnly(feature: action.rawValue)
        }
    }
}

enum GatedAction: String {
    case runSearch                = "search"
    case runRouteScan             = "route_scan"
    case enableProximityAlerts    = "proximity_alerts"
    case downloadOfflinePack      = "offline_pack"
    case saveRoute                = "save_route"
    case viewReportHistory        = "report_history"
    case viewDensityScore         = "density_score"
}

/// Daily-rotating usage counters. The day boundary keys off a simple
/// `yyyy-MM-dd` string in UserDefaults so the counter resets at local
/// midnight without any cron / push.
struct GatedUsage: Equatable {
    let searchesToday: Int

    static let zero = GatedUsage(searchesToday: 0)
}

/// Tiny helper that persists the daily search counter. Pulled out so views
/// can read & bump it without owning the UserDefaults dance directly.
@MainActor
struct SearchQuotaTracker {
    private static let kDay = "platewatch.searchQuota.day"
    private static let kCount = "platewatch.searchQuota.count"

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date())
    }

    /// Current snapshot. Auto-rolls the counter when the day changes.
    func snapshot() -> GatedUsage {
        rolloverIfNeeded()
        return GatedUsage(searchesToday: defaults.integer(forKey: Self.kCount))
    }

    func bump() {
        rolloverIfNeeded()
        defaults.set(defaults.integer(forKey: Self.kCount) + 1, forKey: Self.kCount)
    }

    private func rolloverIfNeeded() {
        let stored = defaults.string(forKey: Self.kDay) ?? ""
        let today = todayKey
        if stored != today {
            defaults.set(today, forKey: Self.kDay)
            defaults.set(0, forKey: Self.kCount)
        }
    }
}
