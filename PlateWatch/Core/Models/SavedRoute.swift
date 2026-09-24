import Foundation
import CoreLocation

/// A saved route the user wants to scan repeatedly. Premium feature —
/// cloud-synced for SIWA users, local-only otherwise.
struct SavedRoute: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var originLat: Double
    var originLon: Double
    var destinationLat: Double
    var destinationLon: Double
    var createdAt: Date
    var lastScannedAt: Date?
    var lastDensityScore: Double?

    var originCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: originLat, longitude: originLon)
    }

    var destinationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: destinationLat, longitude: destinationLon)
    }

    init(
        id: UUID = UUID(),
        name: String,
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        createdAt: Date = Date(),
        lastScannedAt: Date? = nil,
        lastDensityScore: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.originLat = origin.latitude
        self.originLon = origin.longitude
        self.destinationLat = destination.latitude
        self.destinationLon = destination.longitude
        self.createdAt = createdAt
        self.lastScannedAt = lastScannedAt
        self.lastDensityScore = lastDensityScore
    }
}
