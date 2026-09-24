import SwiftUI
import StoreKit
import AuthenticationServices

/// Settings — Subscribe, Premium Status, Camera Ahead Alerts toggle (with
/// always-location prompt), Sign In with Apple (premium-only sync), About,
/// Privacy Policy, Terms of Use, Reset App Data, Delete Account (SIWA only).
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("portfolio.analytics.opted_out") private var analyticsOptedOut: Bool = false

    @State private var showPaywall = false
    @State private var showResetConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var siwaError: String?
    @State private var hasSiwaCredential: Bool = false

    /// Apple's user-facing Sign in with Apple account manager. Per Apple's
    /// SIWA review guidelines, an in-app delete-account path may complete
    /// locally as long as the user is told how to fully revoke the SIWA
    /// grant via Apple's UI. The /v1/account REST endpoint that would do
    /// the server-side row wipe + Apple-side token revocation is gated on
    /// API v1.1 (currently stubbed at 501); until that ships, we direct the
    /// user to this URL.
    private let siwaManagerURL = URL(string: "https://appleid.apple.com/account/manage")!

    var body: some View {
        // Was `Form { … }` — on iPadOS 18+/26 SwiftUI, a `Form` containing a
        // `SignInWithAppleButton` inside a `NavigationStack` can zero-size its
        // whole layout and render blank. `List` is the direct swap with the
        // same section semantics and doesn't trigger the SIWA rendering bug.
        List {
            subscriptionSection
            cameraAheadSection
            cloudSyncSection
            privacySection
            aboutSection
            dataSection
            #if DEBUG
            debugSection
            #endif
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationDestination(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("Delete all data?", isPresented: $showResetConfirm) {
            Button("Delete", role: .destructive) { appState.resetAppData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This wipes the install trial stamp, onboarding state, and the local entitlement on this device. The local camera cache is preserved so the map still works offline. You can re-grant trial state by reinstalling the app.")
        }
        .alert("Delete your PlateAware account?", isPresented: $showDeleteAccountConfirm) {
            Button("Delete & open Apple ID", role: .destructive) {
                appState.resetAppData()
                hasSiwaCredential = false
                #if canImport(UIKit)
                UIApplication.shared.open(siwaManagerURL)
                #endif
                PortfolioAnalytics.shared.track("account.delete_confirmed",
                                                ["auth": "siwa"])
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This signs you out of saved-routes sync and clears all PlateAware data from this device. To fully remove your Apple ID grant, visit appleid.apple.com → Sign-In & Security → Sign in with Apple, find PlateAware, and tap Stop Using Apple ID. We'll open that page for you after you confirm.")
        }
        .alert("Sign in failed", isPresented: Binding(
            get: { siwaError != nil },
            set: { if !$0 { siwaError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(siwaError ?? "")
        }
        .onAppear {
            PortfolioAnalytics.shared.track(PortfolioEvent.screenViewed,
                                            ["screen": "settings"])
        }
    }

    // MARK: - Sections

    private var subscriptionSection: some View {
        Section("Subscription") {
            HStack {
                Text("Status")
                Spacer()
                Text(statusText)
                    .foregroundStyle(Theme.textSecondary)
            }
            if appState.purchaseManager.isInIntroTrial {
                HStack {
                    Image(systemName: "gift.fill").foregroundStyle(Theme.primary)
                    Text("Trial: \(appState.purchaseManager.introTrialDaysRemaining) days left")
                    Spacer()
                }
                .font(.subheadline)
            }
            Button {
                showPaywall = true
            } label: {
                Label(appState.purchaseManager.isPro ? "Change plan" : "Upgrade", systemImage: "sparkles")
            }
            Button {
                Task { await appState.purchaseManager.restore() }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
            }
            if appState.purchaseManager.isPro {
                Button {
                    showManageSubscriptions()
                } label: {
                    Label("Manage Subscription", systemImage: "creditcard")
                }
            }
        }
    }

    private var cameraAheadSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { appState.proximityAlertsEnabled },
                set: { newValue in
                    if newValue {
                        let decision = EntitlementGate.evaluate(
                            .enableProximityAlerts,
                            entitlement: appState.entitlement,
                            usage: .zero
                        )
                        guard decision == .allowed else {
                            showPaywall = true
                            PortfolioAnalytics.shared.track(
                                PortfolioEvent.featureBlockedByPaywall,
                                ["feature": "proximity_alerts"]
                            )
                            return
                        }
                        appState.setProximityAlerts(enabled: true)
                        appState.locationService.requestAlwaysAuthorizationIfNeeded()
                    } else {
                        appState.setProximityAlerts(enabled: false)
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Camera Ahead alerts")
                    Text("Local notifications when you approach a known fixed camera. Requires Always location.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        } header: {
            Text("Notifications")
        }
    }

    private var cloudSyncSection: some View {
        Section {
            if hasSiwaCredential {
                Label("Signed in with Apple", systemImage: "person.badge.shield.checkmark.fill")
                    .foregroundStyle(Theme.success)
                Button(role: .destructive) {
                    // SIWA delete account. v1 wipes all local data + opens
                    // Apple's SIWA account manager so the user can revoke the
                    // Apple ID grant. v1.1 will add the server-side DELETE
                    // /v1/account call (currently stubbed at 501); until then
                    // the local wipe + Apple ID revocation surface is the
                    // honest answer per 5.1.1(v) (in-app delete that
                    // completes without an email round-trip).
                    showDeleteAccountConfirm = true
                } label: {
                    Label("Delete Account", systemImage: "trash")
                }
                Text("Deleting your account clears local data and opens Apple's Sign in with Apple manager so you can revoke the grant.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                SignInWithAppleButton(.signIn) { req in
                    req.requestedScopes = [.email]
                } onCompletion: { result in
                    switch result {
                    case .success:
                        hasSiwaCredential = true
                    case .failure(let err):
                        siwaError = err.localizedDescription
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)
                Text("Optional — Sign in with Apple is only used to sync saved routes across your devices (a Pro feature). Anonymous use stays anonymous.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        } header: {
            Text("Cloud sync (Pro)")
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Toggle("Anonymous analytics", isOn: Binding(
                get: { !analyticsOptedOut },
                set: { newValue in
                    analyticsOptedOut = !newValue
                    if newValue {
                        PortfolioAnalytics.shared.optIn()
                    } else {
                        PortfolioAnalytics.shared.optOut()
                    }
                }
            ))
            Text("Counts and outcomes only. Never your location traces or report contents.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(versionString)
                    .foregroundStyle(Theme.textSecondary)
            }
            NavigationLink {
                AboutView()
            } label: {
                Label("Data source & attribution", systemImage: "info.circle")
            }
            Link(destination: PricingConfig.Links.terms) {
                Label("Terms of Use", systemImage: "doc.text")
            }
            Link(destination: PricingConfig.Links.privacy) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label(hasSiwaCredential ? "Reset App Data" : "Delete All Data",
                      systemImage: "trash")
            }
            Text(hasSiwaCredential
                 ? "Wipes the install trial stamp, onboarding state, and the local entitlement on this device. To delete your account fully, use Delete Account in the Cloud sync section above."
                 : "Anonymous users only — wipes the install trial stamp, onboarding state, and the local entitlement on this device. This is the in-app account-deletion path required by App Store guideline 5.1.1(v).")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Debug") {
            Button("Reset install trial") { IntroTrialClock().debugReset() }
            Button("Force trial expiry") { IntroTrialClock().debugExpire() }
            HStack {
                Text("isPremium")
                Spacer()
                Text("\(appState.entitlement.isPremium ? "yes" : "no")")
            }
            HStack {
                Text("installTrialActive")
                Spacer()
                Text("\(appState.entitlement.installTrialActive() ? "yes" : "no")")
            }
            HStack {
                Text("isEntitled")
                Spacer()
                Text("\(appState.entitlement.isEntitled() ? "yes" : "no")")
            }
            HStack {
                Text("cache count")
                Spacer()
                Text("\(appState.cameraStore.count)")
            }
        }
    }
    #endif

    // MARK: - Helpers

    private var statusText: String {
        if appState.entitlement.isPremium { return "Pro" }
        if appState.entitlement.installTrialActive() { return "Trial active" }
        return "Free"
    }

    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (\(build))"
    }

    private func showManageSubscriptions() {
        Task {
            #if canImport(UIKit)
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
            try? await AppStore.showManageSubscriptions(in: scene)
            #endif
        }
    }
}
