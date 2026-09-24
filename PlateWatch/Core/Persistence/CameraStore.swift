import Foundation
import CoreLocation

/// Thread-safe in-memory + JSON-on-disk camera cache. Picked over GRDB or
/// CoreData for the scaffold to keep zero non-Apple dependencies and to make
/// the unit tests trivial; the spec leaves the choice open ("SQLite or
/// CoreData") and BACKEND_PLAN.md notes the on-device dataset is small enough
/// (single-digit MB) that an in-memory index is plenty for v1.
///
/// If/when the dataset grows past ~50k pins we swap the backing store for
/// GRDB without changing the public API.
///
/// Persistence: the full snapshot is written to `Application Support/
/// PlateWatch/cameras.json` after every successful sync upsert. On launch
/// `loadFromDisk()` rehydrates the in-memory index from that file; the
/// `SeedLoader` is only consulted if the file is missing.
@MainActor
final class CameraStore: ObservableObject {
    @Published private(set) var version: String?
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var count: Int = 0

    private var camerasById: [String: Camera] = [:]

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
                base = support.appendingPathComponent("PlateWatch", isDirectory: true)
                try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            } else {
                base = FileManager.default.temporaryDirectory
            }
            self.fileURL = base.appendingPathComponent("cameras.json")
        }
    }

    // MARK: - Public reads

    /// All cameras within `radiusMeters` of the given point. Naive O(n) scan
    /// — fine for the seed dataset; replaced by a geohash bucket index when
    /// the dataset grows past the in-memory threshold.
    func nearby(lat: Double, lon: Double, radiusMeters: Double) -> [Camera] {
        let target = CLLocation(latitude: lat, longitude: lon)
        return camerasById.values.filter { c in
            CLLocation(latitude: c.lat, longitude: c.lon).distance(from: target) <= radiusMeters
        }
    }

    /// All cameras inside the given bounding box.
    func bbox(south: Double, west: Double, north: Double, east: Double) -> [Camera] {
        camerasById.values.filter { c in
            c.lat >= south && c.lat <= north && c.lon >= west && c.lon <= east
        }
    }

    /// Camera count by state code (e.g. "TX") — used by the offline-pack
    /// detail view.
    func stateCount(stateCode: String) -> Int {
        let target = stateCode.uppercased()
        return camerasById.values.reduce(0) { acc, c in
            (c.state?.uppercased() == target) ? acc + 1 : acc
        }
    }

    /// All cameras (used by tests + the offline-pack list overview).
    func allCameras() -> [Camera] {
        Array(camerasById.values)
    }

    // MARK: - Upserts

    /// Idempotent upsert. Apply once per delta payload.
    func upsert(_ cameras: [Camera]) {
        for c in cameras { camerasById[c.id] = c }
        recountAndPersist()
    }

    /// Remove cameras by id (delta `deletes` array).
    func remove(ids: [String]) {
        for id in ids { camerasById.removeValue(forKey: id) }
        recountAndPersist()
    }

    /// Replace the entire dataset (used by seed bootstrap).
    func replaceAll(with cameras: [Camera], version: String?) {
        camerasById = Dictionary(uniqueKeysWithValues: cameras.map { ($0.id, $0) })
        self.version = version
        self.lastSyncedAt = Date()
        recountAndPersist()
    }

    func setVersion(_ version: String) {
        self.version = version
        self.lastSyncedAt = Date()
        persistVersionPointer()
    }

    // MARK: - Persistence

    func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let snapshot = try? decoder.decode(Snapshot.self, from: data) {
            self.camerasById = Dictionary(uniqueKeysWithValues: snapshot.cameras.map { ($0.id, $0) })
            self.version = snapshot.version
            self.lastSyncedAt = snapshot.lastSyncedAt
            self.count = camerasById.count
        }
    }

    private func recountAndPersist() {
        count = camerasById.count
        let snapshot = Snapshot(version: version,
                                lastSyncedAt: lastSyncedAt ?? Date(),
                                cameras: Array(camerasById.values))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func persistVersionPointer() {
        // The snapshot already carries the version on next upsert; rewrite
        // immediately so a sync that updates the pointer without changing
        // rows still persists.
        recountAndPersist()
    }

    private struct Snapshot: Codable {
        let version: String?
        let lastSyncedAt: Date
        let cameras: [Camera]
    }
}
