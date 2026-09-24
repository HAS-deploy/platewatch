import Foundation
import CoreLocation

/// A single camera record. Mirrors the `cameras` table in BACKEND_PLAN.md
/// 1:1 so JSON decoded from the API and JSON decoded from the bundled seed
/// dataset use the same shape.
struct Camera: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let lat: Double
    let lon: Double
    let type: CameraType
    let subtype: String?
    let brand: String?
    let direction: String?
    let roadName: String?
    let city: String?
    let state: String?
    let country: String?
    let source: String?
    let sourceUrl: String?
    let confidenceScore: Double?
    let verifiedStatus: VerifiedStatus
    let firstSeen: Date?
    let lastSeen: Date?
    let updatedAt: Date?
    let tagsJson: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    enum CodingKeys: String, CodingKey {
        case id, lat, lon, type, subtype, brand, direction
        case roadName = "road_name"
        case city, state, country, source
        case sourceUrl = "source_url"
        case confidenceScore = "confidence_score"
        case verifiedStatus = "verified_status"
        case firstSeen = "first_seen"
        case lastSeen = "last_seen"
        case updatedAt = "updated_at"
        case tagsJson = "tags_json"
    }
}
