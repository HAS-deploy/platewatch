import SwiftUI

struct OfflinePacksView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var packManager = StatePackManager()

    var body: some View {
        Group {
            if appState.entitlement.isEntitled() {
                listContent
            } else {
                ProUpsellView(feature: "Offline state packs")
            }
        }
        .navigationTitle("Offline Packs")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var listContent: some View {
        List {
            Section {
                Text("State packs let you load the map without a data connection. Useful in tunnels, parks, and roaming territory.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Section("Available packs") {
                ForEach(StatePackEntry.catalog) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.name)
                            Text("~\(entry.estimatedMB) MB · \(appState.cameraStore.stateCount(stateCode: entry.code)) pins in cache")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        if packManager.isInstalled(entry.code) {
                            Button("Remove") { packManager.remove(stateCode: entry.code) }
                                .foregroundStyle(Theme.danger)
                        } else {
                            Button("Download") { packManager.install(stateCode: entry.code) }
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }
            }
        }
    }
}
