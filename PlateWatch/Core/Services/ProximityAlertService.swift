import Foundation
import CoreLocation
import UserNotifications

/// Premium "Camera Ahead" alerter. Monitors up to 20 (the OS limit per app)
/// CLCircularRegions, one per nearest camera. When the user crosses into a
/// region we fire a local notification. v1 only — no remote APNs.
///
/// Gated by `EntitlementGate.evaluate(.enableProximityAlerts, …)` and by an
/// always-location authorization check. The toggle in Settings is the ONLY
/// path that calls `start()` — we never auto-enable on launch.
@MainActor
final class ProximityAlertService: NSObject, ObservableObject {
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var monitoredRegionCount: Int = 0

    private let manager = CLLocationManager()
    private let center = UNUserNotificationCenter.current()
    private let store: CameraStore

    init(store: CameraStore) {
        self.store = store
        super.init()
        manager.delegate = self
    }

    func start(near coordinate: CLLocationCoordinate2D) async {
        guard manager.authorizationStatus == .authorizedAlways else {
            // Caller is responsible for prompting first.
            return
        }
        let granted = await requestNotificationAuthorization()
        guard granted else { return }
        let nearby = store.nearby(lat: coordinate.latitude,
                                  lon: coordinate.longitude,
                                  radiusMeters: 10_000).prefix(20)
        for c in nearby {
            let region = CLCircularRegion(
                center: c.coordinate,
                radius: 300,
                identifier: "platewatch.proximity.\(c.id)"
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            manager.startMonitoring(for: region)
        }
        isRunning = true
        monitoredRegionCount = manager.monitoredRegions.count
    }

    func stop() {
        for region in manager.monitoredRegions {
            manager.stopMonitoring(for: region)
        }
        isRunning = false
        monitoredRegionCount = 0
    }

    private func requestNotificationAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }
}

extension ProximityAlertService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        // Build a local notification on entry. No data exfiltration —
        // notification content is generated on-device from the static region id.
        let content = UNMutableNotificationContent()
        content.title = "Camera Ahead"
        content.body = "You're approaching a known public camera. Drive aware."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: region.identifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
