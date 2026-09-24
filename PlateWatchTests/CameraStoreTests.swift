import XCTest
import CoreLocation
@testable import PlateWatch

@MainActor
final class CameraStoreTests: XCTestCase {

    private func makeStore() -> CameraStore {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("platewatch-test-\(UUID().uuidString).json")
        return CameraStore(fileURL: tmp)
    }

    private func makeCamera(id: String, lat: Double, lon: Double, type: CameraType = .alpr, state: String = "CA") -> Camera {
        Camera(
            id: id, lat: lat, lon: lon, type: type,
            subtype: nil, brand: nil, direction: nil,
            roadName: nil, city: nil, state: state, country: "US",
            source: "test", sourceUrl: nil,
            confidenceScore: 0.9, verifiedStatus: .verified,
            firstSeen: nil, lastSeen: nil, updatedAt: nil, tagsJson: nil
        )
    }

    func testUpsertIsIdempotent() {
        let store = makeStore()
        let a = makeCamera(id: "a", lat: 37.0, lon: -122.0)
        store.upsert([a, a, a])
        XCTAssertEqual(store.count, 1)
        store.upsert([a])
        XCTAssertEqual(store.count, 1)
    }

    func testNearbyReturnsOnlyWithinRadius() {
        let store = makeStore()
        store.upsert([
            makeCamera(id: "a", lat: 37.0, lon: -122.0),  // anchor
            makeCamera(id: "b", lat: 37.001, lon: -122.001), // ~150m
            makeCamera(id: "z", lat: 47.0, lon: -100.0),   // far away
        ])
        let near = store.nearby(lat: 37.0, lon: -122.0, radiusMeters: 1_000)
        XCTAssertEqual(Set(near.map(\.id)), Set(["a", "b"]))
    }

    func testBboxFilters() {
        let store = makeStore()
        store.upsert([
            makeCamera(id: "in",  lat: 37.5, lon: -122.0),
            makeCamera(id: "out", lat: 40.0, lon: -100.0),
        ])
        let inBox = store.bbox(south: 37.0, west: -123.0, north: 38.0, east: -121.0)
        XCTAssertEqual(inBox.map(\.id), ["in"])
    }

    func testStateCount() {
        let store = makeStore()
        store.upsert([
            makeCamera(id: "1", lat: 1, lon: 1, state: "TX"),
            makeCamera(id: "2", lat: 1, lon: 1, state: "TX"),
            makeCamera(id: "3", lat: 1, lon: 1, state: "CA"),
        ])
        XCTAssertEqual(store.stateCount(stateCode: "TX"), 2)
        XCTAssertEqual(store.stateCount(stateCode: "CA"), 1)
        XCTAssertEqual(store.stateCount(stateCode: "FL"), 0)
    }

    func testRemoveDoesNotAffectOtherRows() {
        let store = makeStore()
        store.upsert([
            makeCamera(id: "a", lat: 1, lon: 1),
            makeCamera(id: "b", lat: 1, lon: 1),
        ])
        store.remove(ids: ["a", "missing"])
        XCTAssertEqual(store.count, 1)
        XCTAssertEqual(store.allCameras().map(\.id), ["b"])
    }
}
