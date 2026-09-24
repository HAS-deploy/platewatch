import SwiftUI

/// Root coordinator. Shows the onboarding flow on first launch, otherwise
/// the main tab structure. Also wires the `-showPaywall` screenshot path.
struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.didCompleteOnboarding {
                RootTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .sheet(isPresented: $appState.autoPresentPaywall) {
            NavigationStack {
                PaywallView()
                    .environmentObject(appState)
            }
        }
    }
}
