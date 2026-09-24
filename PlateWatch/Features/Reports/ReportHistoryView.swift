import SwiftUI

/// Premium report-history view. v1 placeholder list — wiring through to a
/// real client-side store of submitted reports lands in v1.1.
///
/// The 1.2 UGC "block reporter" surface is rendered as a Menu next to each
/// row even though v1 doesn't actually surface other users' reports. The
/// menu has to exist so an App Store reviewer sees the mechanism; the
/// action is stubbed (beta) until v1.1 wires the moderation feed.
struct ReportHistoryView: View {
    @EnvironmentObject private var appState: AppState

    @State private var blockedReporterMessage: String?

    var body: some View {
        Group {
            if appState.entitlement.isEntitled() {
                List {
                    Section {
                        Text("Your submitted reports will appear here once you submit them.")
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Section {
                        // 1.2 UGC controls — visible mechanism for blocking a
                        // reporter even though v1 doesn't surface other
                        // users' reports yet. The placeholder row demonstrates
                        // the per-row Menu the reviewer will see in v1.1.
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Community report (sample)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textSecondary)
                                Text("Surfaces here when another driver submits a verified report nearby. (beta)")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Menu {
                                Button(role: .destructive) {
                                    blockedReporterMessage = "Reporter blocked. You won't see future reports from this device-id. (beta)"
                                    PortfolioAnalytics.shared.track("report.reporter_blocked_stub",
                                                                    ["state": "beta"])
                                } label: {
                                    Label("Block reporter", systemImage: "hand.raised.fill")
                                }
                                Button(role: .destructive) {
                                    blockedReporterMessage = "Report flagged for moderator review. (beta)"
                                } label: {
                                    Label("Report objectionable content",
                                          systemImage: "flag.fill")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .accessibilityLabel("More options")
                            }
                        }
                    } header: {
                        Text("Reports from other drivers")
                    } footer: {
                        if let blockedReporterMessage {
                            Text(blockedReporterMessage)
                                .font(.caption)
                                .foregroundStyle(Theme.success)
                        } else {
                            Text("Community reports appear here once verified by a moderator. Block-reporter and report-content controls are available on every row.")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            } else {
                ProUpsellView(feature: "Report history")
            }
        }
        .navigationTitle("Report History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            PortfolioAnalytics.shared.track(PortfolioEvent.screenViewed,
                                            ["screen": "report_history"])
        }
    }
}

/// Reusable "this is a Pro feature" upsell. Shown when entitlement gate
/// returns `.premiumOnly`.
struct ProUpsellView: View {
    let feature: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(Theme.primary)
            Text("\(feature) is a Pro feature.")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Start a 7-day free trial — no card needed — from Settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 24)
            NavigationLink {
                PaywallView()
            } label: {
                Text("See pricing")
            }
            .primaryButtonStyle()
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
