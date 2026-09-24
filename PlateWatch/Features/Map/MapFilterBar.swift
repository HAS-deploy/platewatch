import SwiftUI

/// Horizontal chip row at the top of the map. Tapping a chip toggles the
/// camera type. State is local to MapView for now — re-promote to AppState
/// if we ever want filter prefs to persist across launches.
struct MapFilterBar: View {
    @Binding var enabledTypes: Set<CameraType>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CameraType.allCases) { type in
                    let enabled = enabledTypes.contains(type)
                    Button {
                        toggle(type)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.iconName)
                            Text(type.displayName)
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(enabled ? Theme.tint(for: type) : Theme.surfaceSecondary)
                        )
                        .foregroundStyle(enabled ? Color.white : Theme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
        )
    }

    private func toggle(_ type: CameraType) {
        if enabledTypes.contains(type) {
            enabledTypes.remove(type)
        } else {
            enabledTypes.insert(type)
        }
    }
}
