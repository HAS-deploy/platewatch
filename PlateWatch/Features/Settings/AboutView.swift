import SwiftUI

/// Data-source attribution panel. The DeFlock community map + OpenStreetMap
/// are the upstream data sources; ODbL requires we credit them clearly.
struct AboutView: View {
    var body: some View {
        Form {
            Section("What PlateAware is") {
                Text("A public-roadway infrastructure transparency map. We show where fixed cameras and school zones are on public roads, using open public datasets — for privacy and infrastructure awareness.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            DataSourceCreditView()
            Section("Contact") {
                Link(destination: URL(string: "mailto:support@plateaware.app")!) {
                    Label("support@plateaware.app", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
