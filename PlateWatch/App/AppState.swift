import Foundation
import SwiftUI
import CoreLocation
import Combine

/// Cross-cutting runtime state for PlateWatch. Owns the entitlement struct,
/// the StoreKit handle, the camera store + sync coordinator, and the
/// location service. Views read from here via `@EnvironmentObject`.
///
/// Note on lifecycle: `bootstrap()` is async-called once from
/// `PlateWatchApp.body.task`. It seeds the camera store from the bundled
/// JSON if empty, fires a one-shot sync (best-effort), then starts the
/// StoreKit listener.
@MainActor
final class AppState: ObservableObject {
    @Published var didCompleteOnboarding: Bool =
        UserDefaults.standard.bool(forKey: "platewatch.onboarding.complete")
    @Published var hasRequestedLocationOnce: Bool =
        UserDefaults.standard.bool(forKey: "platewatch.location.requested")
    @Published var proximityAlertsEnabled: Bool =
        UserDefaults.standard.bool(forKey: "platewatch.proximityAlerts.enabled")
    @Published var didBootstrapFromLocation: Bool =
        UserDefaults.standard.bool(forKey: "platewatch.bootstrapped_from_location")

    /// Timestamp of the last successful DeFlock refresh — used to throttle
    /// the per-launch refresh so a rapid app-switch doesn't spam Overpass.
    private var lastCameraRefreshAt: Date? {
        get {
            let t = UserDefaults.standard.double(forKey: "platewatch.last_camera_refresh_at")
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970,
                                          forKey: "platewatch.last_camera_refresh_at")
            } else {
                UserDefaults.standard.removeObject(forKey: "platewatch.last_camera_refresh_at")
            }
        }
    }

    /// Set true at launch if `-showPaywall` argument is present. Used by
    /// the screenshot pipeline.
    @Published var autoPresentPaywall: Bool =
        CommandLine.arguments.contains("-showPaywall")

    let entitlement = UserEntitlement()
    let purchaseManager: PurchaseManager
    let cameraStore = CameraStore()
    let savedRouteStore = SavedRouteStore()
    let apiClient = APIClient()
    let locationService = LocationService()
    let deflock = DeFlockClient()

    var syncCoordinator: SyncCoordinator!
    var proximityAlertService: ProximityAlertService!

    private var locationBootstrapCancellable: AnyCancellable?

    init() {
        let entitlement = self.entitlement
        self.purchaseManager = PurchaseManager(entitlement: entitlement)
        self.syncCoordinator = SyncCoordinator(api: apiClient, store: cameraStore)
        self.proximityAlertService = ProximityAlertService(store: cameraStore)
    }

    func bootstrap() async {
        cameraStore.loadFromDisk()
        SeedLoader.loadIfEmpty(into: cameraStore)
        await purchaseManager.start()
        // Fire-and-forget sync. Failures degrade silently to the local cache.
        Task {
            _ = await syncCoordinator.runOnce()
        }
        armLocationBootstrapIfNeeded()
    }

    /// Refresh cameras from DeFlock around the user's current location on every
    /// launch. Throttles to at most once per 60 s so a rapid app-switch doesn't
    /// hammer Overpass. Silent on failure — seed + last snapshot keep the map
    /// non-empty. Waits for the first real location fix after auth is granted.
    private func armLocationBootstrapIfNeeded() {
        if let last = lastCameraRefreshAt, Date().timeIntervalSince(last) < 60 {
            return
        }
        locationBootstrapCancellable = locationService.$currentLocation
            .compactMap { $0 }
            .first()
            .sink { [weak self] loc in
                Task { @MainActor [weak self] in
                    await self?.performLocationBootstrap(loc)
                }
            }
        switch locationService.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationService.requestOneShotLocation()
        default:
            break
        }
    }

    private func performLocationBootstrap(_ loc: CLLocation) async {
        do {
            let cameras = try await deflock.fetchNearby(
                lat: loc.coordinate.latitude,
                lon: loc.coordinate.longitude,
                radiusMeters: 80_000
            )
            if !cameras.isEmpty {
                cameraStore.upsert(cameras)
            }
            didBootstrapFromLocation = true
            UserDefaults.standard.set(true, forKey: "platewatch.bootstrapped_from_location")
            lastCameraRefreshAt = Date()
        } catch {
            // Silent — retry on next launch.
        }
        locationBootstrapCancellable = nil
    }

    /// Fetch cameras inside a route corridor bbox before scoring. RouteScan
    /// calls this after MKDirections returns so the score is against fresh
    /// data. Returns silently on network failure — the local cache still
    /// scores something.
    func refreshCamerasAlongRoute(south: Double, west: Double,
                                  north: Double, east: Double) async {
        let midLat = (south + north) / 2
        let midLon = (west + east) / 2
        // Rough half-diagonal in meters — 111 km per degree lat, slightly less per lon.
        let dLat = (north - south) / 2
        let dLon = (east - west) / 2
        let latMeters = dLat * 111_000
        let lonMeters = dLon * 111_000 * max(cos(midLat * .pi / 180), 0.01)
        let radius = max(sqrt(latMeters * latMeters + lonMeters * lonMeters), 5_000)
        do {
            let cameras = try await deflock.fetchNearby(
                lat: midLat, lon: midLon, radiusMeters: min(radius, 100_000)
            )
            if !cameras.isEmpty {
                cameraStore.upsert(cameras)
            }
        } catch {
            // Silent.
        }
    }

    func completeOnboarding() {
        didCompleteOnboarding = true
        UserDefaults.standard.set(true, forKey: "platewatch.onboarding.complete")
    }

    func markLocationRequested() {
        hasRequestedLocationOnce = true
        UserDefaults.standard.set(true, forKey: "platewatch.location.requested")
    }

    func setProximityAlerts(enabled: Bool) {
        proximityAlertsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "platewatch.proximityAlerts.enabled")
        if !enabled {
            proximityAlertService.stop()
        }
    }

    /// Settings → Reset App Data — wipes local entitlement, install-trial
    /// stamp, onboarding, location-prompt flag, and proximity-alert toggle
    /// so the next launch looks like a fresh install. Works in Release.
    func resetAppData() {
        entitlement.fullReset()
        UserDefaults.standard.removeObject(forKey: "platewatch.onboarding.complete")
        UserDefaults.standard.removeObject(forKey: "platewatch.location.requested")
        UserDefaults.standard.removeObject(forKey: "platewatch.proximityAlerts.enabled")
        UserDefaults.standard.removeObject(forKey: "platewatch.bootstrapped_from_location")
        didCompleteOnboarding = false
        hasRequestedLocationOnce = false
        proximityAlertsEnabled = false
        didBootstrapFromLocation = false
    }
}
