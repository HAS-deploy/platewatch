import Foundation

/// Pointer to the latest dataset version we've successfully ingested. The
/// API returns `{version, manifestUrl}` from `/v1/sync/version`; we persist
/// the last applied version in UserDefaults under `platewatch.sync.version`.
struct SyncVersion: Codable, Equatable, Sendable {
    let version: String
    let manifestUrl: String?
    let publishedAt: Date?
}

/// Delta payload shape returned by `/v1/sync/delta`.
struct SyncDelta: Codable, Sendable {
    let fromVersion: String?
    let toVersion: String
    let upserts: [Camera]
    let deletes: [String]

    enum CodingKeys: String, CodingKey {
        case fromVersion = "from_version"
        case toVersion = "to_version"
        case upserts, deletes
    }
}
