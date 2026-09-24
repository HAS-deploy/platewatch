import Foundation

/// Canonical camera categories. The spec lists these by name; we lock them in
/// an enum so the map filter bar, detail sheet, and report submit form all
/// agree on the legal value set.
enum CameraType: String, Codable, CaseIterable, Identifiable, Sendable {
    case alpr
    case redLight = "red_light"
    case traffic
    case toll
    case schoolZone = "school_zone"
    case speed
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alpr:       return "ALPR"
        case .redLight:   return "Red Light"
        case .traffic:    return "Traffic"
        case .toll:       return "Toll Reader"
        case .schoolZone: return "School Zone"
        case .speed:      return "Speed"
        case .other:      return "Other"
        }
    }

    /// SF Symbol used on the map pin + detail header.
    var iconName: String {
        switch self {
        case .alpr:       return "camera.metering.spot"
        case .redLight:   return "exclamationmark.octagon.fill"
        case .traffic:    return "video.fill"
        case .toll:       return "creditcard.fill"
        case .schoolZone: return "graduationcap.fill"
        case .speed:      return "gauge.with.dots.needle.67percent"
        case .other:      return "questionmark.circle.fill"
        }
    }
}

/// Verification provenance for a record. Mirrors the spec's `verified_status`
/// column.
enum VerifiedStatus: String, Codable, Sendable {
    case unverified
    case verified
    case rejected
}
