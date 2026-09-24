import SwiftUI

/// First-launch 3-step welcome flow. Per the Subscriptions playbook §1.7
/// we do NOT present a modal paywall during onboarding. Order:
///   1. Welcome — what PlateWatch is (privacy framing).
///   2. Location permission — request when-in-use ONLY when the user taps
///      Continue here; never silently at launch.
///   3. Trial intro — "Your 7-day Pro trial is active. No card needed."
///
/// The install-trial clock is already stamped from `PlateWatchApp.init`;
/// this view's job is only to advance past the welcome and into the main
/// app.
struct OnboardingFlowView: View {
    @EnvironmentObject private var appState: AppState
    @State private var page: Int = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                // Paged TabView was swallowing button taps on iPadOS 18. Switched to a
                // state-driven view switch so Continue / Start exploring fire reliably.
                Group {
                    switch page {
                    case 0: welcomePage
                    case 1: locationPage
                    default: trialPage
                    }
                }
                .transition(.opacity)

                if page < 2 {
                    Button("Skip") {
                        appState.completeOnboarding()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                    .padding(.top, 12)
                    .padding(.trailing, 20)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { idx in
                            Circle()
                                .fill(idx == page ? Theme.primary : Theme.textSecondary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
            .background(Theme.surface.ignoresSafeArea())
        }
        .onAppear {
            PortfolioAnalytics.shared.track(PortfolioEvent.onboardingViewed, [:])
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        OnboardingPage(
            icon: "mappin.and.ellipse.circle.fill",
            headline: "See what's already watching the road.",
            subhead: "PlateAware maps fixed cameras — ALPR, red-light, traffic, toll, school zone — using public open data. Privacy and infrastructure transparency.",
            primaryTitle: "Continue",
            primaryAction: { advance() }
        )
    }

    private var locationPage: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 16)
            Image(systemName: "location.viewfinder")
                .font(.system(size: 80, weight: .semibold))
                .foregroundStyle(Theme.primary)
            Text("Center the map on where you are.")
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 24)
            Text("Your approximate location is sent to PlateAware servers only to fetch nearby cameras; we don't store it. Precise background location is used only if you turn on Camera Ahead alerts in Settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    // 5.1.1(iv): the pre-permission sheet must lead directly into
                    // the system prompt — no skip / bypass button. The system prompt
                    // itself is where the user chooses Allow / Don't Allow. If the
                    // user declines at the OS level, the rest of the app remains
                    // fully functional; `advance()` moves onboarding forward
                    // regardless of the OS answer.
                    appState.locationService.requestWhenInUseAuthorizationIfNeeded()
                    appState.markLocationRequested()
                    advance()
                } label: { Text("Continue") }
                .primaryButtonStyle()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 64)
        }
    }

    private var trialPage: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.primary)
                Text("Your 7-day free Pro trial is active.")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textPrimary)
                Text("No card. Pro includes Camera Ahead alerts, route scan, offline state packs, density score, saved routes, and Privacy-preferring route — find low-surveillance routes. Subscribe any time to keep it after day 7.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 24)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(Theme.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 24)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    appState.completeOnboarding()
                    PortfolioAnalytics.shared.track(PortfolioEvent.onboardingCompleted, [:])
                } label: { Text("Start exploring") }
                .primaryButtonStyle()

                NavigationLink {
                    PaywallView()
                } label: {
                    Text("See pricing")
                        .frame(maxWidth: .infinity)
                }
                .secondaryButtonStyle()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 64)
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.25)) {
            page = min(page + 1, 2)
        }
        PortfolioAnalytics.shared.track(PortfolioEvent.onboardingAdvanced,
                                        ["page": page])
    }
}

private struct OnboardingPage: View {
    let icon: String
    let headline: String
    let subhead: String
    let primaryTitle: String
    let primaryAction: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)
            Image(systemName: icon)
                .font(.system(size: 96, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .padding(.bottom, 8)
            Text(headline)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 24)
            Text(subhead)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 32)
            Spacer()
            Button(action: primaryAction) { Text(primaryTitle) }
                .primaryButtonStyle()
                .padding(.horizontal, 24)
                .padding(.bottom, 64)
        }
    }
}
