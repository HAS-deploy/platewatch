import Foundation

/// Premium offline state-pack manager. v1 stub — tracks which state packs
/// are "installed" via UserDefaults. v1.1 swaps in a real downloader that
/// pulls the per-state JSON from S3 and merges into CameraStore.
@MainActor
final class StatePackManager: ObservableObject {
    @Published private(set) var installedStates: Set<String> = []

    private static let kInstalledKey = "platewatch.offlinePacks.installed"

    init() {
        if let arr = UserDefaults.standard.array(forKey: Self.kInstalledKey) as? [String] {
            installedStates = Set(arr)
        }
    }

    func install(stateCode: String) {
        installedStates.insert(stateCode.uppercased())
        persist()
    }

    func remove(stateCode: String) {
        installedStates.remove(stateCode.uppercased())
        persist()
    }

    func isInstalled(_ stateCode: String) -> Bool {
        installedStates.contains(stateCode.uppercased())
    }

    private func persist() {
        UserDefaults.standard.set(Array(installedStates), forKey: Self.kInstalledKey)
    }
}

/// Catalog of the state packs the user can install. v1 is a fixed list —
/// the spec calls out Texas as the first pack so it's at the top.
struct StatePackEntry: Identifiable, Hashable {
    let code: String
    let name: String
    let estimatedMB: Int
    var id: String { code }

    static let catalog: [StatePackEntry] = [
        StatePackEntry(code: "TX", name: "Texas",       estimatedMB: 14),
        StatePackEntry(code: "CA", name: "California",  estimatedMB: 22),
        StatePackEntry(code: "NY", name: "New York",    estimatedMB: 16),
        StatePackEntry(code: "FL", name: "Florida",     estimatedMB: 11),
        StatePackEntry(code: "IL", name: "Illinois",    estimatedMB:  9),
        StatePackEntry(code: "WA", name: "Washington",  estimatedMB:  7),
    ]
}
