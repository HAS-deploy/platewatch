import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// PlateWatch color + typography system. Cool-blue privacy/safety palette
/// with a warm accent on the route-risk score. Everything in the app reads
/// from `Theme` instead of hardcoding hex.
enum Theme {
    // Primary blue — privacy/transparency vibe; used for accent, primary CTA,
    // map current-location dot.
    static let primary = Color(red: 0.231, green: 0.510, blue: 0.961)         // #3B82F6
    static let primaryDark = Color(red: 0.153, green: 0.388, blue: 0.804)     // #2763CD
    static let primarySoft = Color(red: 0.910, green: 0.940, blue: 0.984)     // very light blue

    // Status palette
    static let success = Color(red: 0.176, green: 0.616, blue: 0.361)         // #2D9D5C
    static let successSoft = Color(red: 0.890, green: 0.961, blue: 0.918)
    static let warning = Color(red: 0.878, green: 0.522, blue: 0.188)         // #E08530
    static let warningSoft = Color(red: 1.000, green: 0.949, blue: 0.882)
    static let danger = Color(red: 0.820, green: 0.271, blue: 0.271)          // #D14545
    static let dangerSoft = Color(red: 1.000, green: 0.918, blue: 0.918)

    // Neutrals — adapt automatically to light/dark mode
    static let surface = Color(uiColor: .systemBackground)
    static let surfaceSecondary = Color(uiColor: .secondarySystemBackground)
    static let surfaceTertiary = Color(uiColor: .tertiarySystemBackground)
    static let outline = Color(uiColor: .separator)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    /// Per-camera-type pin tints. Used on the map + detail sheet header.
    static func tint(for type: CameraType) -> Color {
        switch type {
        case .alpr:       return Color(red: 0.85, green: 0.30, blue: 0.42)    // pinkish red
        case .redLight:   return Color(red: 0.95, green: 0.30, blue: 0.30)    // red
        case .traffic:    return Color(red: 0.30, green: 0.55, blue: 0.95)    // blue
        case .toll:       return Color(red: 0.50, green: 0.40, blue: 0.90)    // purple
        case .schoolZone: return Color(red: 0.95, green: 0.70, blue: 0.10)    // amber
        case .speed:      return Color(red: 0.95, green: 0.45, blue: 0.20)    // orange
        case .other:      return Color(uiColor: .secondaryLabel)
        }
    }
}

// MARK: - View styling helpers

extension View {
    /// Standard rounded card.
    func platewatchCard() -> some View {
        self
            .padding(16)
            .background(Theme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Primary blue filled CTA.
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// Outlined secondary button.
    func secondaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(Theme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.primary, lineWidth: 1.5)
            )
    }
}
