import SwiftUI

@main
struct PlateWatchApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Start analytics first — every other lifecycle event needs it. The
        // canonical `app` register call happens inside `start(appName:)` so
        // every event after this carries the `app` property per memory
        // `feedback_portfolio_analytics_must_fix`.
        PortfolioAnalytics.shared.start(appName: "platewatch")

        // Stamp install-trial start the first time the app ever launches.
        // Idempotent — subsequent launches never overwrite.
        IntroTrialClock().recordInstallIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .task {
                    await appState.bootstrap()
                }
        }
    }
}
