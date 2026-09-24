import SwiftUI

/// Custom map pin per camera type. SF Symbol on a colored disc. Designed to
/// be readable at the default zoom of a city-block-scale map view.
struct CameraPinAnnotation: View {
    let type: CameraType

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.tint(for: type))
                .frame(width: 32, height: 32)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            Image(systemName: type.iconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(type.displayName)
    }
}
