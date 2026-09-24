import Foundation
import Combine
import CoreLocation

/// Persists user-saved routes (origin + destination + friendly name) so the
/// Directions tab can re-run a scan without re-typing the addresses.
/// Storage: JSON on disk under `Application Support/PlateWatch/saved-routes.json`.
/// Same-shape ambition as `CameraStore` — plain Codable, no CoreData/GRDB.
/// Pro-only feature (per SavedRoute doc); the view layer guards the toggle.
@MainActor
final class SavedRouteStore: ObservableObject {
    @Published private(set) var routes: [SavedRoute] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base: URL
            if let support = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ) {
                let dir = support.appendingPathComponent("PlateWatch", isDirectory: true)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                base = dir
            } else {
                base = FileManager.default.temporaryDirectory
            }
            self.fileURL = base.appendingPathComponent("saved-routes.json")
        }
        loadFromDisk()
    }

    // MARK: - Reads

    func route(with id: UUID) -> SavedRoute? {
        routes.first(where: { $0.id == id })
    }

    // MARK: - Writes

    /// Insert or replace by id. Preserves creation date if the route
    /// already existed; overwrites all other fields.
    func upsert(_ route: SavedRoute) {
        if let idx = routes.firstIndex(where: { $0.id == route.id }) {
            var existing = routes[idx]
            existing.name = route.name
            existing.originLat = route.originLat
            existing.originLon = route.originLon
            existing.destinationLat = route.destinationLat
            existing.destinationLon = route.destinationLon
            existing.lastScannedAt = route.lastScannedAt ?? existing.lastScannedAt
            existing.lastDensityScore = route.lastDensityScore ?? existing.lastDensityScore
            routes[idx] = existing
        } else {
            routes.append(route)
        }
        persist()
    }

    /// Record a fresh scan result against an already-saved route.
    func markScanned(id: UUID, densityScore: Double?) {
        guard let idx = routes.firstIndex(where: { $0.id == id }) else { return }
        routes[idx].lastScannedAt = Date()
        if let densityScore { routes[idx].lastDensityScore = densityScore }
        persist()
    }

    func remove(id: UUID) {
        routes.removeAll(where: { $0.id == id })
        persist()
    }

    func removeAll() {
        routes.removeAll()
        persist()
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([SavedRoute].self, from: data) {
            self.routes = decoded
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(routes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
