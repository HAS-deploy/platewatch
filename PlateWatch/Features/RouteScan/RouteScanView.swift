import SwiftUI
import MapKit
import CoreLocation

/// Premium "scan a route before you drive" view.
///
/// Two modes:
///   - **Fastest** (free) — picks the first route MapKit returns. Shows the
///     camera-count chips for context.
///   - **Privacy route** (premium) — sorts MKDirections alternatives by
///     ALPR-camera intersections ascending and highlights the
///     lowest-surveillance route with a "Privacy recommended" badge. The
///     user makes the final selection; the app never auto-routes.
///
/// Inputs: two coordinates — either typed as free-text addresses
/// (geocoded via `CLGeocoder`) or pulled from the user's current location
/// via `LocationService`. No third-party geocoder.
///
/// Premium gating: the Privacy route toggle calls `EntitlementGate.evaluate`
/// for `.runRouteScan`; non-entitled users see the paywall and the mode
/// stays on `.fastest`.
///
/// Copy rules (locked by the risk profile §0 Privacy-preferring route mode
/// section): every visible string MUST use privacy / civil-liberties
/// framing. The strings "avoid", "evade", "beat", "bypass", "around",
/// "skip", "ticket", "police", "officer", "detect", "law enforcement" MUST
/// NOT appear anywhere in this view. `RouteScanTests.testForbiddenWordsAbsentFromUserStrings`
/// is the static defense against regression.
struct RouteScanView: View {
    @EnvironmentObject private var appState: AppState

    /// Optional pre-fill when opened from a saved route tap.
    let prefill: SavedRoute?

    init(prefill: SavedRoute? = nil) {
        self.prefill = prefill
    }

    // Inputs
    @State private var originText: String = ""
    @State private var destinationText: String = ""
    @State private var originCoordinate: CLLocationCoordinate2D?
    @State private var destinationCoordinate: CLLocationCoordinate2D?

    // Save-this-route UX
    @State private var showSaveSheet = false
    @State private var saveName: String = ""
    @State private var linkedSavedRouteId: UUID?

    // Mode + selection
    @State private var mode: RouteScanMode = .fastest
    @State private var alternatives: [RouteAlternative] = []
    @State private var selectedAlternativeId: UUID?

    // Map camera
    @State private var cameraPosition: MapCameraPosition = .automatic

    // Lifecycle / error UX
    @State private var isCalculating = false
    @State private var errorMessage: String?
    @State private var showPaywall = false

    private var sortedAlternatives: [RouteAlternative] {
        switch mode {
        case .fastest:
            return alternatives
        case .privacyPreferring:
            // Lowest ALPR intersection count first, then by travel time for ties.
            return alternatives.sorted { lhs, rhs in
                if lhs.alprCount != rhs.alprCount { return lhs.alprCount < rhs.alprCount }
                return lhs.mkRoute.expectedTravelTime < rhs.mkRoute.expectedTravelTime
            }
        }
    }

    private var selectedAlternative: RouteAlternative? {
        if let id = selectedAlternativeId,
           let match = alternatives.first(where: { $0.id == id }) {
            return match
        }
        return sortedAlternatives.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                modePicker
                inputCard
                if isCalculating {
                    ProgressView("Building route alternatives…")
                        .padding(.vertical, 16)
                }
                if let errorMessage {
                    errorBanner(errorMessage)
                }
                if !alternatives.isEmpty {
                    mapPreview
                    legend
                    alternativesList
                    saveRouteButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Theme.surface.ignoresSafeArea())
        .navigationTitle("Route Scan")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showSaveSheet) {
            saveSheet
        }
        .onAppear {
            PortfolioAnalytics.shared.track(PortfolioEvent.screenViewed,
                                            ["screen": "route_scan"])
            applyPrefillIfNeeded()
        }
    }

    private func applyPrefillIfNeeded() {
        guard let prefill else { return }
        originText = prefill.name.isEmpty ? "Start" : prefill.name + " — Start"
        destinationText = prefill.name.isEmpty ? "End" : prefill.name + " — End"
        originCoordinate = prefill.originCoordinate
        destinationCoordinate = prefill.destinationCoordinate
        linkedSavedRouteId = prefill.id
        saveName = prefill.name
    }

    private var saveRouteButton: some View {
        Group {
            if let origin = originCoordinate, let dest = destinationCoordinate {
                Button {
                    // Pre-populate the save-name field from linked route or a
                    // sane default. Pro gate happens on submit inside the sheet.
                    if saveName.isEmpty {
                        saveName = defaultSaveName()
                    }
                    showSaveSheet = true
                } label: {
                    Label(linkedSavedRouteId == nil ? "Save this route" : "Update saved route",
                          systemImage: "bookmark.fill")
                }
                .secondaryButtonStyle()
                .disabled(origin.latitude == 0 && dest.latitude == 0)
            }
        }
    }

    private func defaultSaveName() -> String {
        let o = originText.trimmingCharacters(in: .whitespaces)
        let d = destinationText.trimmingCharacters(in: .whitespaces)
        if !o.isEmpty && !d.isEmpty { return "\(o) → \(d)" }
        return "Saved \(Date().formatted(date: .abbreviated, time: .shortened))"
    }

    private var saveSheet: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Home → Office", text: $saveName)
                        .textInputAutocapitalization(.words)
                }
                Section {
                    Button("Save") { commitSave() }
                        .disabled(saveName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !appState.entitlement.isEntitled() {
                    Section {
                        Text("Saving routes is a Pro feature. Free plan can still plan and view routes.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .navigationTitle(linkedSavedRouteId == nil ? "Save Route" : "Update Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSaveSheet = false }
                }
            }
        }
    }

    private func commitSave() {
        guard let origin = originCoordinate, let dest = destinationCoordinate else { return }
        // Pro gate — free users see paywall instead of persist.
        let decision = EntitlementGate.evaluate(
            .runRouteScan,
            entitlement: appState.entitlement,
            usage: .zero
        )
        guard decision == .allowed else {
            showSaveSheet = false
            showPaywall = true
            PortfolioAnalytics.shared.track(PortfolioEvent.featureBlockedByPaywall,
                                            ["feature": "save_route"])
            return
        }
        let densityScore = selectedAlternative.map { Double($0.totalCameras) }
        let route = SavedRoute(
            id: linkedSavedRouteId ?? UUID(),
            name: saveName.trimmingCharacters(in: .whitespaces),
            origin: origin,
            destination: dest,
            lastScannedAt: Date(),
            lastDensityScore: densityScore
        )
        appState.savedRouteStore.upsert(route)
        linkedSavedRouteId = route.id
        showSaveSheet = false
        PortfolioAnalytics.shared.track("directions.route_saved",
                                        ["density_score": densityScore ?? -1])
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Route mode", selection: Binding(
                get: { mode },
                set: { setMode($0) }
            )) {
                ForEach(RouteScanMode.allCases) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .pickerStyle(.segmented)

            Text(mode == .privacyPreferring
                 ? "Privacy-preferring route alternatives. Premium."
                 : "Standard fastest route picked by Apple maps.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .background(Theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Input card

    private var inputCard: some View {
        VStack(spacing: 12) {
            inputRow(
                title: "Start",
                placeholder: "Address or place",
                text: $originText,
                useCurrentLocationAction: { useCurrentLocation(for: .origin) }
            )
            inputRow(
                title: "End",
                placeholder: "Address or place",
                text: $destinationText,
                useCurrentLocationAction: { useCurrentLocation(for: .destination) }
            )
            Button {
                Task { await runScan() }
            } label: {
                Text(isCalculating ? "Working…" : "Scan route")
            }
            .primaryButtonStyle()
            .disabled(isCalculating)
        }
        .padding(14)
        .background(Theme.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func inputRow(title: String,
                          placeholder: String,
                          text: Binding<String>,
                          useCurrentLocationAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            HStack {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
                    .submitLabel(.done)
                Button {
                    useCurrentLocationAction()
                } label: {
                    Image(systemName: "location.fill")
                        .foregroundStyle(Theme.primary)
                }
                .accessibilityLabel("Use current location for \(title)")
            }
            .padding(10)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Map preview

    private var mapPreview: some View {
        Map(position: $cameraPosition) {
            ForEach(sortedAlternatives) { alt in
                if alt.id == (selectedAlternativeId ?? sortedAlternatives.first?.id) {
                    MapPolyline(alt.mkRoute.polyline)
                        .stroke(Theme.primary, lineWidth: 6)
                } else {
                    MapPolyline(alt.mkRoute.polyline)
                        .stroke(Theme.textSecondary.opacity(0.55), lineWidth: 4)
                }
            }
            ForEach(camerasAlongSelected, id: \.id) { camera in
                Annotation(camera.type.displayName, coordinate: camera.coordinate) {
                    CameraPinAnnotation(type: camera.type)
                }
            }
        }
        .mapControls { MapCompass(); MapScaleView() }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var camerasAlongSelected: [Camera] {
        guard let alt = selectedAlternative else { return [] }
        let coords = RouteRiskService(store: appState.cameraStore)
            .extractCoordinates(from: alt.mkRoute.polyline)
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        guard let south = lats.min(), let north = lats.max(),
              let west = lons.min(), let east = lons.max() else { return [] }
        let pad = 0.005
        let candidates = appState.cameraStore.bbox(
            south: south - pad,
            west: west - pad,
            north: north + pad,
            east: east + pad
        )
        return candidates.filter { c in
            coords.contains(where: { coord in
                CLLocation(latitude: c.lat, longitude: c.lon)
                    .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude)) <= 60
            })
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(Theme.primary).frame(width: 18, height: 4)
                Text("Selected").font(.caption2).foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(Theme.textSecondary.opacity(0.55)).frame(width: 18, height: 4)
                Text("Alternative").font(.caption2).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Alternatives list

    private var alternativesList: some View {
        VStack(spacing: 10) {
            ForEach(Array(sortedAlternatives.enumerated()), id: \.element.id) { idx, alt in
                Button {
                    selectedAlternativeId = alt.id
                    refocusCamera(on: alt)
                } label: {
                    alternativeRow(index: idx, alternative: alt)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func alternativeRow(index: Int, alternative: RouteAlternative) -> some View {
        let isSelected = alternative.id == (selectedAlternativeId ?? sortedAlternatives.first?.id)
        let showBadge = (mode == .privacyPreferring) && alternative.isPrivacyRecommended

        return HStack(alignment: .top, spacing: 12) {
            VStack {
                Image(systemName: showBadge ? "lock.shield.fill" : "circle.fill")
                    .font(.title3)
                    .foregroundStyle(showBadge ? Theme.success : Theme.primary.opacity(0.6))
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Route \(index + 1)")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    if showBadge {
                        Text("Privacy recommended")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.success.opacity(0.18))
                            .foregroundStyle(Theme.success)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Text(alternative.formattedExpectedTravelTime)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }
                Text(alternative.formattedLength)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    countChip(label: "ALPR",
                              value: alternative.alprCount,
                              tint: Theme.tint(for: .alpr))
                    countChip(label: "Total cameras",
                              value: alternative.totalCameras,
                              tint: Theme.primary)
                }
            }
        }
        .padding(12)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Theme.primary : Theme.outline,
                        lineWidth: isSelected ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func countChip(label: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.warning)
            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
        .padding(12)
        .background(Theme.warningSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Actions

    private enum InputField { case origin, destination }

    private func useCurrentLocation(for field: InputField) {
        appState.locationService.requestWhenInUseAuthorizationIfNeeded()
        appState.locationService.requestOneShotLocation()
        guard let loc = appState.locationService.currentLocation else {
            errorMessage = "Couldn't read your current location. Try typing the address."
            return
        }
        let label = "Current location"
        switch field {
        case .origin:
            originText = label
            originCoordinate = loc.coordinate
        case .destination:
            destinationText = label
            destinationCoordinate = loc.coordinate
        }
    }

    private func setMode(_ newMode: RouteScanMode) {
        let resolved = RouteScanModeGate.resolve(requested: newMode,
                                                 entitlement: appState.entitlement)
        if resolved != newMode {
            // The gate kicked us back to .fastest — surface the paywall as a
            // side-effect. The mode is already pinned correctly by the gate
            // so `testFreeTierCannotPickPrivacyRoute` is satisfied.
            showPaywall = true
            PortfolioAnalytics.shared.track(PortfolioEvent.featureBlockedByPaywall,
                                            ["feature": "privacy_route"])
        }
        mode = resolved
        PortfolioAnalytics.shared.track("route_scan.mode_changed",
                                        ["mode": resolved.rawValue])
    }

    private func runScan() async {
        errorMessage = nil
        isCalculating = true
        defer { isCalculating = false }

        do {
            let origin = try await resolveCoordinate(for: .origin)
            let destination = try await resolveCoordinate(for: .destination)
            let provider: DirectionsProvider = MKDirectionsProvider()
            let routes = try await provider.calculate(from: origin, to: destination)
            guard !routes.isEmpty else {
                errorMessage = "We couldn't build a route between these points."
                return
            }
            // Refresh cameras along the corridor before scoring so the counts
            // reflect current DeFlock data, not just the local cache.
            let service = RouteRiskService(store: appState.cameraStore)
            let allCoords: [CLLocationCoordinate2D] = routes.flatMap { route in
                service.extractCoordinates(from: route.polyline)
            }
            if let south = allCoords.map(\.latitude).min(),
               let north = allCoords.map(\.latitude).max(),
               let west = allCoords.map(\.longitude).min(),
               let east = allCoords.map(\.longitude).max() {
                let pad = 0.02
                await appState.refreshCamerasAlongRoute(
                    south: south - pad, west: west - pad,
                    north: north + pad, east: east + pad
                )
            }
            let scored = service.scoreAlternatives(routes)
            self.alternatives = scored
            self.selectedAlternativeId = (mode == .privacyPreferring
                                          ? scored.min(by: { $0.alprCount < $1.alprCount })?.id
                                          : scored.first?.id)
            if let first = self.alternatives.first {
                refocusCamera(on: first)
            }
            PortfolioAnalytics.shared.track("route_scan.completed",
                                            ["alternatives": scored.count,
                                             "mode": mode.rawValue,
                                             "lowest_alpr": scored.map(\.alprCount).min() ?? 0])
        } catch let RouteScanError.geocodeFailed(field) {
            errorMessage = "We couldn't find a place that matched \"\(field)\". Check spelling or use the current-location button."
        } catch {
            // MKDirections / network failure — vendor-neutral copy per the
            // copy-rules constraint.
            errorMessage = "We couldn't build a route between these points. Check your connection and try again."
        }
    }

    private enum RouteScanError: Error {
        case geocodeFailed(String)
    }

    private func resolveCoordinate(for field: InputField) async throws -> CLLocationCoordinate2D {
        let text: String
        let coord: CLLocationCoordinate2D?
        switch field {
        case .origin:
            text = originText
            coord = originCoordinate
        case .destination:
            text = destinationText
            coord = destinationCoordinate
        }
        if let coord, !text.isEmpty { return coord }
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw RouteScanError.geocodeFailed(text)
        }
        // Apple-only geocoder per spec constraint.
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(text)
        guard let location = placemarks.first?.location else {
            throw RouteScanError.geocodeFailed(text)
        }
        let resolved = location.coordinate
        switch field {
        case .origin: originCoordinate = resolved
        case .destination: destinationCoordinate = resolved
        }
        return resolved
    }

    private func refocusCamera(on alt: RouteAlternative) {
        let rect = alt.mkRoute.polyline.boundingMapRect
        let pad = rect.size.width * 0.15
        let padded = MKMapRect(origin: MKMapPoint(x: rect.origin.x - pad,
                                                  y: rect.origin.y - pad),
                               size: MKMapSize(width: rect.size.width + pad * 2,
                                               height: rect.size.height + pad * 2))
        cameraPosition = .rect(padded)
    }
}
