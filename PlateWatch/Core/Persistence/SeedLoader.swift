import Foundation

/// Loads the bundled `seed-cameras.json` into the CameraStore on first
/// launch. This file is the 4.2-mitigation: a US-wide thin snapshot that
/// guarantees the reviewer sees pins on the first map render even before
/// the API has answered.
enum SeedLoader {
    @MainActor
    static func loadIfEmpty(into store: CameraStore) {
        guard store.count == 0 else { return }
        guard let url = Bundle.main.url(forResource: "seed-cameras", withExtension: "json") else {
            return
        }
        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // The bundled seed file may be either a flat array or a wrapper with
        // a version + cameras array. Try wrapper first.
        if let snapshot = try? decoder.decode(SeedSnapshot.self, from: data) {
            store.replaceAll(with: snapshot.cameras, version: snapshot.version)
            return
        }
        if let cameras = try? decoder.decode([Camera].self, from: data) {
            store.replaceAll(with: cameras, version: "seed-2026-06-11")
        }
    }

    private struct SeedSnapshot: Codable {
        let version: String
        let cameras: [Camera]
    }
}
