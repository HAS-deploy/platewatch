import XCTest
import CoreLocation
@testable import PlateWatch

/// Direct application of a SyncDelta into a CameraStore. The full
/// SyncCoordinator → APIClient flow needs network mocking; we cover the
/// idempotency + delta-application logic here without a network roundtrip.
@MainActor
final class SyncCoordinatorTests: XCTestCase {

    private func makeStore() -> CameraStore {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("platewatch-sync-\(UUID().uuidString).json")
        return CameraStore(fileURL: tmp)
    }

    private func makeCamera(_ id: String) -> Camera {
        Camera(
            id: id, lat: 37.3, lon: -122.0, type: .alpr,
            subtype: nil, brand: nil, direction: nil,
            roadName: nil, city: "Cupertino", state: "CA", country: "US",
            source: "test", sourceUrl: nil, confidenceScore: 0.9,
            verifiedStatus: .verified, firstSeen: nil, lastSeen: nil,
            updatedAt: nil, tagsJson: nil
        )
    }

    /// Apply a delta: upserts land, deletes remove, version pointer advances.
    func testDeltaApplicationIsIdempotent() {
        let store = makeStore()
        store.upsert([makeCamera("a"), makeCamera("b")])
        store.setVersion("v1")

        // Simulate the delta payload the SyncCoordinator would receive.
        let delta = SyncDelta(
            fromVersion: "v1",
            toVersion: "v2",
            upserts: [makeCamera("c"), makeCamera("a")], // upsert overlaps with existing
            deletes: ["b", "missing"]
        )
        store.upsert(delta.upserts)
        store.remove(ids: delta.deletes)
        store.setVersion(delta.toVersion)
        XCTAssertEqual(Set(store.allCameras().map(\.id)), Set(["a", "c"]))
        XCTAssertEqual(store.version, "v2")

        // Applying the same delta again is a no-op (idempotent).
        store.upsert(delta.upserts)
        store.remove(ids: delta.deletes)
        XCTAssertEqual(Set(store.allCameras().map(\.id)), Set(["a", "c"]))
    }

    /// Persisting + reloading round-trips the in-memory state to disk
    /// without losing rows.
    func testPersistsAndReloads() {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("platewatch-persist-\(UUID().uuidString).json")
        let s1 = CameraStore(fileURL: tmp)
        s1.upsert([makeCamera("a"), makeCamera("b")])
        s1.setVersion("v1")

        let s2 = CameraStore(fileURL: tmp)
        s2.loadFromDisk()
        XCTAssertEqual(s2.count, 2)
        XCTAssertEqual(s2.version, "v1")
    }
}
