import SwiftUI

/// Four-tab structure: Map | Saved | Report | Settings. Map is index 0 so
/// the very first thing the reviewer sees on the dense Cupertino seed area
/// is a map full of pins.
struct RootTabView: View {
    /// `-initialTab N` (0..3) drives the screenshot automation flow.
    @State private var selection: Int = {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-initialTab"),
           i + 1 < args.count,
           let n = Int(args[i + 1]), (0...3).contains(n) {
            return n
        }
        return 0
    }()

    var body: some View {
        // iPadOS 18 renders the legacy `.tabItem` TabView as a floating top bar
        // with customization overflow that can eat the Settings tap. The new
        // `Tab` API + explicit `.tabViewStyle(.tabBarOnly)` keeps a plain tab
        // bar on both iPhone and iPad so every tab switches on a single tap.
        // Default iPadOS 18+ style (top floating pill) — the earlier
        // `.tabViewStyle(.tabBarOnly)` did not actually force a plain tab bar
        // on iPad, so we removed it. Bottom tab bar on iPad would require a
        // custom tab bar; leaving that as a follow-up. Single-tap switching
        // works on the default style now that Settings itself renders.
        TabView(selection: $selection) {
            NavigationStack { MapView() }
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(0)

            NavigationStack { DirectionsView() }
                .tabItem { Label("Directions", systemImage: "arrow.triangle.turn.up.right.circle.fill") }
                .tag(1)

            NavigationStack { ReportSubmitView() }
                .tabItem { Label("Report", systemImage: "exclamationmark.bubble.fill") }
                .tag(2)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(Theme.primary)
    }
}
