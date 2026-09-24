import SwiftUI

/// Sheet shown when a user taps a pin. Surfaces every field on `Camera`
/// (matching the spec's `cameras` columns), plus a "Report Inaccuracy" link
/// that deep-links into the report submit flow with the type + lat/lon
/// prefilled. An overflow menu in the nav bar surfaces the 1.2 UGC controls
/// — "Report inaccurate" (= prefilled inaccuracy form) and "Report
/// objectionable content" (free-text reason that POSTs to /v1/reports with
/// type=objectionable_content).
struct CameraDetailSheet: View {
    @EnvironmentObject private var appState: AppState
    let camera: Camera

    @State private var showObjectionableSheet = false
    @State private var showInaccuracyReport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    VStack(alignment: .leading, spacing: 4) {
                        if let road = camera.roadName {
                            row("Road", road)
                        }
                        if let city = camera.city, let state = camera.state {
                            row("Location", "\(city), \(state)")
                        }
                        if let dir = camera.direction {
                            row("Direction", dir)
                        }
                        if let brand = camera.brand {
                            row("Brand", brand)
                        }
                        if let subtype = camera.subtype {
                            row("Subtype", subtype)
                        }
                    }
                    .platewatchCard()

                    sourceCard

                    timestampsCard

                    reportLink
                }
                .padding(16)
            }
            .navigationTitle(camera.type.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showInaccuracyReport = true
                        } label: {
                            Label("Report this pin as inaccurate",
                                  systemImage: "exclamationmark.bubble")
                        }
                        Button(role: .destructive) {
                            showObjectionableSheet = true
                        } label: {
                            Label("Report objectionable content",
                                  systemImage: "flag.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel("More options")
                    }
                }
            }
            .sheet(isPresented: $showObjectionableSheet) {
                ObjectionableContentReportSheet(cameraId: camera.id)
                    .environmentObject(appState)
            }
            .navigationDestination(isPresented: $showInaccuracyReport) {
                ReportSubmitView(prefilledType: camera.type,
                                 prefilledCoordinate: camera.coordinate,
                                 prefilledNote: "Inaccuracy on record \(camera.id)")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CameraPinAnnotation(type: camera.type)
                .scaleEffect(1.3)
                .padding(.trailing, 4)
            VStack(alignment: .leading) {
                Text(camera.type.displayName)
                    .font(.title3.weight(.bold))
                Text(camera.verifiedStatus == .verified ? "Verified" : "Unverified")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(camera.verifiedStatus == .verified ? Theme.success : Theme.warning)
            }
        }
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Source")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            if let source = camera.source {
                Text(source)
                    .font(.subheadline)
            }
            if let conf = camera.confidenceScore {
                Text("Confidence \(Int(conf * 100))%")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            if let urlStr = camera.sourceUrl, let url = URL(string: urlStr) {
                Link("Open source record", destination: url)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .platewatchCard()
    }

    private var timestampsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let firstSeen = camera.firstSeen {
                row("First seen", DateFormatter.medium.string(from: firstSeen))
            }
            if let lastSeen = camera.lastSeen {
                row("Last seen", DateFormatter.medium.string(from: lastSeen))
            }
            if let updatedAt = camera.updatedAt {
                row("Updated", DateFormatter.medium.string(from: updatedAt))
            }
            row("Coordinates", String(format: "%.5f, %.5f", camera.lat, camera.lon))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .platewatchCard()
    }

    private var reportLink: some View {
        NavigationLink {
            ReportSubmitView(prefilledType: camera.type,
                             prefilledCoordinate: camera.coordinate,
                             prefilledNote: "Inaccuracy on record \(camera.id)")
        } label: {
            Label("Report inaccuracy", systemImage: "flag")
                .frame(maxWidth: .infinity)
        }
        .secondaryButtonStyle()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }
}

private extension DateFormatter {
    static let medium: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

/// 1.2 objectionable-content reporter. Free-text reason + camera id POSTed
/// as `type=objectionable_content` against `/v1/reports`. v1 surfaces this
/// even though no user-submitted content is rendered to other users yet —
/// the reviewer-visible mechanism is the point of the rule.
struct ObjectionableContentReportSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let cameraId: String

    @State private var reason: String = ""
    @State private var inFlight = false
    @State private var resultMessage: String?
    @State private var resultIsError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Tell us what's wrong with this pin's content — hate, harassment, doxing, or anything else that violates our community guidelines. A moderator will review.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Section("Reason") {
                    TextField("What should the moderator know?",
                              text: $reason,
                              axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Button("Submit report") {
                        Task { await submit() }
                    }
                    .primaryButtonStyle()
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 6)
                    .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || inFlight)
                }

                if let resultMessage {
                    Section {
                        Text(resultMessage)
                            .font(.subheadline)
                            .foregroundStyle(resultIsError ? Theme.danger : Theme.success)
                    }
                }
            }
            .navigationTitle("Report content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        inFlight = true
        defer { inFlight = false }
        do {
            let response = try await appState.apiClient.submitObjectionableContentReport(
                cameraId: cameraId,
                reason: reason
            )
            resultMessage = "Report queued. ID: \(response.id). A moderator will review it."
            resultIsError = false
            PortfolioAnalytics.shared.track("report.objectionable_submitted",
                                            ["camera_id": cameraId])
        } catch APIClient.APIError.offline {
            resultMessage = "Reports require an internet connection. We'll save the form so you can try again."
            resultIsError = true
        } catch {
            resultMessage = "Couldn't submit: \(error.localizedDescription)"
            resultIsError = true
        }
    }
}
