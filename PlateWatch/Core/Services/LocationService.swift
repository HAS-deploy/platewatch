import Foundation
import CoreLocation
import Combine

/// CoreLocation wrapper. Holds auth state + the latest location reading. The
/// HARD RULE per the risk profile + task spec: this service NEVER requests
/// authorization at construction or at app launch. The caller decides when
/// to prompt — either:
///   - the user taps "Center on me" or the map view first appears
///     (whenInUse), or
///   - the user toggles on Camera Ahead alerts in Settings (always).
@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var lastError: String?

    private let manager = CLLocationManager()

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Just-in-time when-in-use prompt. No-op if already granted.
    func requestWhenInUseAuthorizationIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            PortfolioAnalytics.shared.trackPermission(.location, state: .requested,
                                                     triggerFeature: "map_when_in_use")
            manager.requestWhenInUseAuthorization()
        default: break
        }
    }

    /// Settings-toggle-driven escalation to always. Prereq is when-in-use
    /// already granted (Apple's required sequence).
    func requestAlwaysAuthorizationIfNeeded() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            PortfolioAnalytics.shared.trackPermission(.location, state: .requested,
                                                     triggerFeature: "camera_ahead_alerts")
            manager.requestAlwaysAuthorization()
        case .notDetermined:
            // Caller didn't enforce the sequence — bounce through whenInUse first.
            requestWhenInUseAuthorizationIfNeeded()
        default: break
        }
    }

    /// Request a one-shot location fix. Caller is responsible for having
    /// already prompted for authorization.
    func requestOneShotLocation() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            requestWhenInUseAuthorizationIfNeeded()
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            let state: PermissionState
            switch status {
            case .authorizedAlways, .authorizedWhenInUse: state = .granted
            case .denied, .restricted: state = .denied
            case .notDetermined: state = .deferred
            @unknown default: state = .deferred
            }
            PortfolioAnalytics.shared.trackPermission(.location, state: state)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = loc
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.lastError = error.localizedDescription
        }
    }
}
