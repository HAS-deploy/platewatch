import SwiftUI

/// ODbL attribution panel. Camera data is derived from DeFlock + OSM under
/// the Open Database License — we credit them and link out.
struct DataSourceCreditView: View {
    var body: some View {
        Section("Data sources") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Camera locations are pulled weekly from the DeFlock community map, which is itself anchored on OpenStreetMap.")
                    .font(.subheadline)
                Text("© DeFlock contributors · © OpenStreetMap contributors")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text("Made available under the Open Database License (ODbL). PlateAware's derived data and any user-submitted reports inherit the same license.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 16) {
                    Link("DeFlock map", destination: URL(string: "https://maps.deflock.org")!)
                    Link("OpenStreetMap", destination: URL(string: "https://www.openstreetmap.org")!)
                    Link("ODbL", destination: URL(string: "https://opendatacommons.org/licenses/odbl/")!)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.primary)
            }
        }
    }
}
