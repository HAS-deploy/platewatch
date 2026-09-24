import Foundation

/// Owns the launch-time delta-sync flow. Sequence:
///   1. Read the last applied `version` from `CameraStore`.
///   2. Call `GET /v1/sync/version` — if the server's version matches, no-op.
///   3. Otherwise call `GET /v1/sync/delta?since_version=…` and apply
///      upserts + deletes idempotently into `CameraStore`.
///   4. Persist the new version pointer.
///
/// Failures are swallowed gracefully — a sync miss never blocks the UI, the
/// app degrades to whatever is in the local cache (seed dataset at worst).
@MainActor
final class SyncCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case syncing
        case upToDate
        case applied(toVersion: String, upserted: Int, deleted: Int)
        case failed(reason: String)
    }

    @Published private(set) var state: State = .idle

    private let api: APIClient
    private let store: CameraStore

    init(api: APIClient, store: CameraStore) {
        self.api = api
        self.store = store
    }

    /// One-shot launch-time sync. Returns true if any change was applied.
    @discardableResult
    func runOnce() async -> Bool {
        state = .syncing
        do {
            let serverVersion = try await api.fetchVersion()
            if serverVersion.version == store.version {
                state = .upToDate
                return false
            }
            let delta = try await api.fetchDelta(sinceVersion: store.version)
            store.upsert(delta.upserts)
            store.remove(ids: delta.deletes)
            store.setVersion(delta.toVersion)
            state = .applied(toVersion: delta.toVersion,
                             upserted: delta.upserts.count,
                             deleted: delta.deletes.count)
            return true
        } catch {
            state = .failed(reason: error.localizedDescription)
            return false
        }
    }
}
