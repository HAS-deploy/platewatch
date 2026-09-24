import SwiftUI
import CoreLocation

/// Submit a camera report. Available to free + premium users (the spec
/// allows everyone to contribute). On submit we POST to `/v1/reports`; the
/// Reachability fallback message ("Reports require an internet connection")
/// is the canonical 7th acceptance criterion in the task brief.
struct ReportSubmitView: View {
    @EnvironmentObject private var appState: AppState

    let prefilledType: CameraType?
    let prefilledCoordinate: CLLocationCoordinate2D?
    let prefilledNote: String?

    @State private var type: CameraType = .alpr
    @State private var latText: String = ""
    @State private var lonText: String = ""
    @State private var note: String = ""
    @State private var useCurrentLocation: Bool = false
    @State private var consentChecked: Bool = false
    @State private var inFlight = false
    @State private var resultMessage: String?
    @State private var resultIsError: Bool = false

    init(prefilledType: CameraType? = nil,
         prefilledCoordinate: CLLocationCoordinate2D? = nil,
         prefilledNote: String? = nil) {
        self.prefilledType = prefilledType
        self.prefilledCoordinate = prefilledCoordinate
        self.prefilledNote = prefilledNote
    }

    var body: some View {
        Form {
            Section("Camera type") {
                Picker("Type", selection: $type) {
                    ForEach(CameraType.allCases) { t in
                        Label(t.displayName, systemImage: t.iconName).tag(t)
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Location") {
                Toggle("Use my current location", isOn: $useCurrentLocation)
                if !useCurrentLocation {
                    TextField("Latitude", text: $latText)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $lonText)
                        .keyboardType(.decimalPad)
                }
            }

            Section("Note (optional)") {
                TextField("Anything we should know? e.g. \"removed last month\"", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Consent") {
                Toggle(isOn: $consentChecked) {
                    Text("I confirm this report is about fixed public infrastructure visible from a public road, not a person, vehicle, or private property.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Section {
                Button("Submit report") {
                    Task { await submit() }
                }
                .primaryButtonStyle()
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 6)
                .disabled(!consentChecked || inFlight)
            }

            if let resultMessage {
                Section {
                    Text(resultMessage)
                        .font(.subheadline)
                        .foregroundStyle(resultIsError ? Theme.danger : Theme.success)
                }
            }
        }
        .navigationTitle("Submit a Report")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { applyPrefills() }
    }

    private func applyPrefills() {
        if let t = prefilledType { type = t }
        if let c = prefilledCoordinate {
            latText = String(format: "%.5f", c.latitude)
            lonText = String(format: "%.5f", c.longitude)
        }
        if let n = prefilledNote { note = n }
        PortfolioAnalytics.shared.track(PortfolioEvent.screenViewed,
                                        ["screen": "report_submit"])
    }

    private func resolveCoordinate() -> CLLocationCoordinate2D? {
        if useCurrentLocation {
            return appState.locationService.currentLocation?.coordinate
        }
        guard let lat = Double(latText), let lon = Double(lonText) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func submit() async {
        guard let coord = resolveCoordinate() else {
            resultMessage = "Tell us where the camera is — either toggle on current location or enter coordinates."
            resultIsError = true
            return
        }
        let report = CameraReport(
            type: type,
            coordinate: coord,
            note: note.isEmpty ? nil : note
        )
        inFlight = true
        defer { inFlight = false }
        do {
            let response = try await appState.apiClient.submitReport(report)
            resultMessage = "Report queued. ID: \(response.id). A moderator will review it before it appears on the map."
            resultIsError = false
            PortfolioAnalytics.shared.track("report.submitted",
                                            ["type": type.rawValue])
        } catch APIClient.APIError.offline {
            // CANONICAL Reachability fallback message — explicit per the
            // task brief's 7th acceptance criterion.
            resultMessage = "Reports require an internet connection. We'll save the form so you can try again."
            resultIsError = true
            PortfolioAnalytics.shared.trackError(code: "report.offline",
                                                 screen: "report_submit",
                                                 severity: .warn,
                                                 feature: "reports")
        } catch {
            resultMessage = "Couldn't submit: \(error.localizedDescription)"
            resultIsError = true
            PortfolioAnalytics.shared.trackError(code: "report.submit_failed",
                                                 screen: "report_submit",
                                                 severity: .error,
                                                 feature: "reports")
        }
    }
}
