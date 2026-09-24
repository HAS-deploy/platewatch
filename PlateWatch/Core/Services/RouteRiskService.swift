import Foundation
import CoreLocation
import MapKit

/// Premium route-risk scanner. Two layers:
///
///  1. Legacy `scan(_:)` — accepts a hand-rolled polyline (`[CLLocationCoordinate2D]`)
///     and returns the corridor camera count + density score the original
///     scaffold relied on. Retained because the saved-route scaffold + a few
///     screenshot flows still feed straight-line samples.
///  2. New `scoreAlternatives(_:)` — accepts an array of `MKRoute` returned
///     by `MKDirections.calculate(...)` and decorates each with the
///     PlateWatch camera-density overlay used by the Privacy route mode
///     picker (`RouteAlternative`).
///
/// The new path uses a tighter corridor (50 m, per the risk profile + spec)
/// because MKDirections returns real road geometry — we no longer need the
/// 250 m generous corridor that hid sampling noise in the straight-line stub.
///
/// Brute-force nearest-distance check from each candidate camera to each
/// segment. For the bundled seed dataset (<1000 pins) and typical driving
/// routes (<5000 polyline points) this is well under the per-scan budget.
@MainActor
struct RouteRiskService {
    struct Result: Equatable {
        let totalCameras: Int
        let byType: [CameraType: Int]
        let densityScore: Double        // 0-100; higher = denser
        let routeLengthMeters: Double
    }

    let store: CameraStore
    /// Legacy `scan(_:)` corridor.
    var corridorMeters: Double = 250
    /// New `scoreAlternatives` corridor — the spec/risk-profile-locked 50 m
    /// "within 50m of the polyline" threshold.
    var routeMatchMeters: Double = 50

    // MARK: - Legacy straight-line scan (kept for back-compat)

    func scan(_ polyline: [CLLocationCoordinate2D]) -> Result {
        guard polyline.count >= 2 else {
            return Result(totalCameras: 0, byType: [:], densityScore: 0, routeLengthMeters: 0)
        }

        let segments = zip(polyline, polyline.dropFirst()).map { ($0, $1) }
        let routeLength = segments.reduce(0.0) { acc, seg in
            acc + CLLocation(latitude: seg.0.latitude, longitude: seg.0.longitude)
                .distance(from: CLLocation(latitude: seg.1.latitude, longitude: seg.1.longitude))
        }

        // Coarse bounding-box filter first to skip the obvious nope set.
        let lats = polyline.map(\.latitude)
        let lons = polyline.map(\.longitude)
        let bboxPadDeg = 0.01 // ~1 km
        let candidates = store.bbox(
            south: (lats.min() ?? 0) - bboxPadDeg,
            west:  (lons.min() ?? 0) - bboxPadDeg,
            north: (lats.max() ?? 0) + bboxPadDeg,
            east:  (lons.max() ?? 0) + bboxPadDeg
        )

        var hitsByType: [CameraType: Int] = [:]
        var total = 0
        for c in candidates {
            let distance = minDistance(from: c.coordinate, to: segments)
            if distance <= corridorMeters {
                total += 1
                hitsByType[c.type, default: 0] += 1
            }
        }

        let perKm = routeLength > 0 ? Double(total) / (routeLength / 1000.0) : 0
        let score = min(100.0, perKm * 50.0)

        return Result(totalCameras: total,
                      byType: hitsByType,
                      densityScore: score,
                      routeLengthMeters: routeLength)
    }

    // MARK: - MKRoute alternative scoring

    /// Pure helper: given a vector of per-route ALPR intersection counts,
    /// return a Bool array the same length where exactly one slot is `true`
    /// — the slot with the minimum count. Ties break to the first index.
    /// Exposed so tests can verify the recommendation logic without having
    /// to mint real `MKRoute` instances (Apple's framework doesn't ship a
    /// public initializer).
    static func privacyRecommendedFlags(forAlprCounts counts: [Int]) -> [Bool] {
        guard !counts.isEmpty else { return [] }
        guard let lowest = counts.min() else { return Array(repeating: false, count: counts.count) }
        var seenLowest = false
        return counts.map { c in
            if !seenLowest && c == lowest {
                seenLowest = true
                return true
            }
            return false
        }
    }

    /// Score each MKDirections alternative against the local camera store.
    /// Returns `RouteAlternative` objects, one per input route, with the
    /// `isPrivacyRecommended` flag set on the single lowest-ALPR alternative.
    /// Ties break to the first alternative seen.
    func scoreAlternatives(_ routes: [MKRoute]) -> [RouteAlternative] {
        guard !routes.isEmpty else { return [] }
        let scored = routes.map { route -> (UUID, MKRoute, Int, Int, [CameraType: Int]) in
            let polyline = extractCoordinates(from: route.polyline)
            let (alprCount, totalCount, byType) = countCamerasAlong(polyline: polyline)
            return (UUID(), route, alprCount, totalCount, byType)
        }
        let flags = Self.privacyRecommendedFlags(forAlprCounts: scored.map(\.2))
        return zip(scored, flags).map { tuple, recommend in
            let (id, route, alpr, total, byType) = tuple
            return RouteAlternative(
                id: id,
                mkRoute: route,
                alprCount: alpr,
                totalCameras: total,
                camerasByType: byType,
                isPrivacyRecommended: recommend
            )
        }
    }

    /// Pure helper that runs the per-camera distinct-intersection scoring
    /// used by `scoreAlternatives(...)`. Public so the tests can exercise
    /// the deduplication invariant directly (a single ALPR camera near two
    /// adjacent polyline points must be counted ONCE).
    func countCamerasAlong(polyline: [CLLocationCoordinate2D])
        -> (alprCount: Int, totalCount: Int, byType: [CameraType: Int]) {
        guard polyline.count >= 2 else { return (0, 0, [:]) }
        let segments = zip(polyline, polyline.dropFirst()).map { ($0, $1) }

        let lats = polyline.map(\.latitude)
        let lons = polyline.map(\.longitude)
        let bboxPadDeg = 0.01
        let candidates = store.bbox(
            south: (lats.min() ?? 0) - bboxPadDeg,
            west:  (lons.min() ?? 0) - bboxPadDeg,
            north: (lats.max() ?? 0) + bboxPadDeg,
            east:  (lons.max() ?? 0) + bboxPadDeg
        )

        var matchedIds = Set<String>()
        var alprIds = Set<String>()
        var byType: [CameraType: Int] = [:]
        for camera in candidates {
            let distance = minDistance(from: camera.coordinate, to: segments)
            if distance <= routeMatchMeters {
                // Distinct-only: a camera near two adjacent polyline points
                // counts once because we key off `camera.id`.
                if matchedIds.insert(camera.id).inserted {
                    byType[camera.type, default: 0] += 1
                    if camera.type == .alpr {
                        alprIds.insert(camera.id)
                    }
                }
            }
        }
        return (alprIds.count, matchedIds.count, byType)
    }

    /// Convert an `MKPolyline` into an `[CLLocationCoordinate2D]` array via
    /// `getCoordinates(_:range:)`. Pulled out so the routes-and-coordinates
    /// path is testable in isolation.
    func extractCoordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        let count = polyline.pointCount
        guard count > 0 else { return [] }
        var coords = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: count
        )
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
        return coords
    }

    // MARK: - Geometry helpers

    /// Minimum great-circle distance (approximated as planar within the bbox)
    /// from a point to any segment in the polyline.
    private func minDistance(from point: CLLocationCoordinate2D,
                             to segments: [(CLLocationCoordinate2D, CLLocationCoordinate2D)]) -> Double {
        var best = Double.greatestFiniteMagnitude
        for (a, b) in segments {
            let d = distanceFromPointToSegment(point, a: a, b: b)
            if d < best { best = d }
        }
        return best
    }

    private func distanceFromPointToSegment(_ p: CLLocationCoordinate2D,
                                            a: CLLocationCoordinate2D,
                                            b: CLLocationCoordinate2D) -> Double {
        let midLat = (a.latitude + b.latitude) / 2
        let metersPerDegLat = 111_320.0
        let metersPerDegLon = 111_320.0 * cos(midLat * .pi / 180)

        let ax = a.longitude * metersPerDegLon
        let ay = a.latitude * metersPerDegLat
        let bx = b.longitude * metersPerDegLon
        let by = b.latitude * metersPerDegLat
        let px = p.longitude * metersPerDegLon
        let py = p.latitude * metersPerDegLat

        let abx = bx - ax
        let aby = by - ay
        let apx = px - ax
        let apy = py - ay
        let abLenSq = abx * abx + aby * aby
        if abLenSq == 0 { return hypot(apx, apy) }
        let t = max(0, min(1, (apx * abx + apy * aby) / abLenSq))
        let cx = ax + t * abx
        let cy = ay + t * aby
        return hypot(px - cx, py - cy)
    }
}

// MARK: - MKDirections wrapper

/// Thin wrapper over MKDirections.calculate that returns up to 3 route
/// alternatives between two coordinates. Pulled out of `RouteScanView` so
/// the view stays declarative and so the call site can be swapped in tests.
///
/// The default implementation calls Apple's framework directly; the protocol
/// lets the test suite inject a stub that returns pre-canned `MKRoute`
/// instances without a live network.
protocol DirectionsProvider {
    func calculate(from origin: CLLocationCoordinate2D,
                   to destination: CLLocationCoordinate2D) async throws -> [MKRoute]
}

struct MKDirectionsProvider: DirectionsProvider {
    func calculate(from origin: CLLocationCoordinate2D,
                   to destination: CLLocationCoordinate2D) async throws -> [MKRoute] {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        return response.routes
    }
}
