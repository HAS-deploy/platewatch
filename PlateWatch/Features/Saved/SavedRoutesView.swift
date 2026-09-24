import SwiftUI

/// Directions tab root. Primary content is the RouteScan planner; saved
/// routes list below lets Pro users tap a row to re-load into the planner
/// and re-scan. Free users can still plan routes; saving is Pro-gated
/// inside RouteScanView's save sheet.
///
/// File retains its original name so RootTabView + the rest of the code
/// keeps compiling without a rename, but the type is now `DirectionsView`.
/// The old `SavedRoutesView` symbol is kept as a deprecated alias.
struct DirectionsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var storeAnchor = StoreAnchor()

    /// Route to prefill on the next planner render — set when the user
    /// taps a saved-route row.
    @State private var pendingPrefill: SavedRoute?
    /// Force RouteScanView to remount when we hand it a new prefill.
    @State private var plannerKey = UUID()

    var body: some View {
        List {
            Section {
                RouteScanView(prefill: pendingPrefill)
                    .id(plannerKey)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            Section("Saved routes") {
                if !appState.entitlement.isEntitled() {
                    NavigationLink {
                        ProUpsellView(feature: "Saved routes")
                    } label: {
                        Label("Save routes with Pro", systemImage: "bookmark.fill")
                    }
                } else if appState.savedRouteStore.routes.isEmpty {
                    Text("Plan a route above and tap Save this route to reuse it here.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(appState.savedRouteStore.routes) { route in
                        Button {
                            loadIntoPlanner(route)
                        } label: {
                            SavedRouteRow(route: route)
                        }
                    }
                    .onDelete { indexSet in
                        for idx in indexSet {
                            let route = appState.savedRouteStore.routes[idx]
                            appState.savedRouteStore.remove(id: route.id)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Directions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            PortfolioAnalytics.shared.track(PortfolioEvent.screenViewed,
                                            ["screen": "directions"])
            // Keep the List reactive to store updates.
            storeAnchor.attach(store: appState.savedRouteStore)
        }
    }

    private func loadIntoPlanner(_ route: SavedRoute) {
        pendingPrefill = route
        plannerKey = UUID()
        PortfolioAnalytics.shared.track("directions.route_reloaded",
                                        ["route_id": route.id.uuidString])
    }
}

/// SwiftUI can't observe an `@EnvironmentObject`'s nested @Published
/// arrays for auto-refresh reliably across NavigationStack pushes; this
/// anchor forwards changes into the enclosing view's identity so the
/// saved-routes list re-renders on upsert / remove.
@MainActor
private final class StoreAnchor: ObservableObject {
    private var attached = false
    private var subscription: AnyObject?

    func attach(store: SavedRouteStore) {
        guard !attached else { return }
        attached = true
        // Cheap subscription — force @Published propagation.
        subscription = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        } as AnyObject
    }
}

@available(*, deprecated, renamed: "DirectionsView")
typealias SavedRoutesView = DirectionsView
