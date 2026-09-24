import Foundation
import MapKit

/// View-model wrapper around RouteRiskService.Result with formatted
/// presentation values. Created here so the result view can stay layout-only.
///
/// The legacy struct (`RouteScanResult`) is retained for callers that still
/// scan a hand-rolled polyline. The new `RouteAlternative` struct wraps a
/// real `MKRoute` from MKDirections and carries the per-route ALPR /
/// total-cameras counts that the Privacy route mode picker reads from.
struct RouteScanResult: Equatable {
    let totalCameras: Int
    let byType: [CameraType: Int]
    let densityScore: Double
    let routeLengthMeters: Double

    init(from result: RouteRiskService.Result) {
        self.totalCameras = result.totalCameras
        self.byType = result.byType
        self.densityScore = result.densityScore
        self.routeLengthMeters = result.routeLengthMeters
    }

    var formattedLength: String {
        let miles = routeLengthMeters / 1609.34
        return String(format: "%.1f mi", miles)
    }

    var formattedScore: String {
        "\(Int(densityScore))/100"
    }
}

/// A single MKDirections alternative with PlateWatch's privacy-scoring
/// overlay applied. The `mkRoute` is retained verbatim so the map view can
/// render its polyline; the counts are precomputed against the local camera
/// store so the row chips render synchronously.
///
/// Identity: a stable `UUID` per alternative — `MKRoute` is not `Hashable`,
/// and routes returned by MKDirections do not carry a stable identifier we
/// can hash against, so we mint one when scoring runs. Use `id` for SwiftUI
/// list identity and `==`/`hash`-by-id semantics.
struct RouteAlternative: Identifiable, Hashable {
    let id: UUID
    let mkRoute: MKRoute
    /// Distinct ALPR cameras (`camera.type == .alpr`) within 50 m of the
    /// route polyline. The same camera near two adjacent polyline points
    /// counts once.
    let alprCount: Int
    /// Distinct cameras of ANY type within 50 m of the route polyline.
    let totalCameras: Int
    let camerasByType: [CameraType: Int]
    /// True only for the alternative with the lowest `alprCount` among the
    /// set returned by `RouteRiskService.scoreAlternatives(...)`. Ties break
    /// to the first alternative seen.
    let isPrivacyRecommended: Bool

    static func == (lhs: RouteAlternative, rhs: RouteAlternative) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var formattedLength: String {
        let miles = mkRoute.distance / 1609.34
        return String(format: "%.1f mi", miles)
    }

    var formattedExpectedTravelTime: String {
        let minutes = Int(mkRoute.expectedTravelTime / 60)
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours) hr \(mins) min"
    }
}

/// Top-level mode for the Route Scan picker. Default is `.fastest` (free
/// tier). `.privacyPreferring` requires premium entitlement and sorts the
/// alternatives by `alprCount` ascending so the lowest-ALPR route surfaces
/// at the top.
enum RouteScanMode: String, CaseIterable, Identifiable {
    case fastest
    case privacyPreferring

    var id: String { rawValue }

    /// User-facing label. Vetted against the forbidden-words list — never
    /// uses "avoid", "evade", "bypass", etc.
    var displayName: String {
        switch self {
        case .fastest:           return "Fastest"
        case .privacyPreferring: return "Privacy route"
        }
    }
}

/// Pure mode-selection rule extracted so the test suite can exercise it
/// without instantiating the SwiftUI view. Returns the mode the picker
/// SHOULD land on given the user's intent and current entitlement state.
///
/// - Premium / inside trial → honor the requested mode.
/// - Free tier + requested `.privacyPreferring` → stays on `.fastest` (the
///   view layer is responsible for presenting the paywall side-effect).
@MainActor
enum RouteScanModeGate {
    static func resolve(requested: RouteScanMode,
                        entitlement: UserEntitlement,
                        now: Date = Date()) -> RouteScanMode {
        switch requested {
        case .fastest:
            return .fastest
        case .privacyPreferring:
            return entitlement.isEntitled(now: now) ? .privacyPreferring : .fastest
        }
    }
}
