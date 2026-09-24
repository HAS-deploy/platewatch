import Foundation
import CoreLocation

/// A user-submitted camera report. Stored locally for the report history
/// (premium feature) and POSTed to `/v1/reports` for moderation.
struct CameraReport: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let type: CameraType
    let lat: Double
    let lon: Double
    let note: String?
    /// Local file URL of the optional attached photo. Sent as multipart on
    /// upload; not present in API responses.
    var localPhotoPath: String?
    let submittedAt: Date
    /// Moderation status set by the server once the report has been reviewed.
    var moderationStatus: ModerationStatus
    /// Server-assigned ID once the report has been accepted. Local UUID is
    /// the source of truth client-side.
    var serverId: String?

    enum ModerationStatus: String, Codable, Sendable {
        case pendingUpload = "pending_upload"
        case queued
        case verified
        case rejected
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    init(
        id: UUID = UUID(),
        type: CameraType,
        coordinate: CLLocationCoordinate2D,
        note: String? = nil,
        localPhotoPath: String? = nil,
        submittedAt: Date = Date(),
        moderationStatus: ModerationStatus = .pendingUpload,
        serverId: String? = nil
    ) {
        self.id = id
        self.type = type
        self.lat = coordinate.latitude
        self.lon = coordinate.longitude
        self.note = note
        self.localPhotoPath = localPhotoPath
        self.submittedAt = submittedAt
        self.moderationStatus = moderationStatus
        self.serverId = serverId
    }
}
