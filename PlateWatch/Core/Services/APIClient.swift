import Foundation

/// Thin URLSession wrapper for the PlateWatch HTTP API. Base URL is read
/// from `Info.plist → APIBaseURL`; falls back to the documented production
/// host. Every method is `async throws` and returns a typed model.
///
/// NOTE: per BACKEND_PLAN.md the iOS app never hits the API for per-query
/// nearby/bbox reads — it reads from the local `CameraStore` cache. The API
/// only carries the delta-sync payload + report submissions + account state.
actor APIClient {
    enum APIError: Error, LocalizedError {
        case badStatus(Int)
        case decodeFailed(String)
        case offline
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .badStatus(let code): return "Server returned \(code)."
            case .decodeFailed(let m): return "Response wasn't in the expected shape: \(m)"
            case .offline:             return "You're offline. Reports require an internet connection."
            case .unknown(let m):      return m
            }
        }
    }

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL? = nil, session: URLSession = .shared) {
        if let baseURL {
            self.baseURL = baseURL
        } else if let str = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
                  let url = URL(string: str) {
            self.baseURL = url
        } else {
            self.baseURL = URL(string: "https://api.plateaware.app")!
        }
        self.session = session
    }

    // MARK: - Sync

    func fetchVersion() async throws -> SyncVersion {
        try await get("/v1/sync/version", as: SyncVersion.self)
    }

    func fetchDelta(sinceVersion: String?) async throws -> SyncDelta {
        var path = "/v1/sync/delta"
        if let sinceVersion {
            path += "?since_version=\(sinceVersion)"
        }
        return try await get(path, as: SyncDelta.self)
    }

    // MARK: - Reports

    func submitReport(_ report: CameraReport) async throws -> ReportSubmitResponse {
        let body: [String: Any] = [
            "client_id": report.id.uuidString,
            "type": report.type.rawValue,
            "lat": report.lat,
            "lon": report.lon,
            "note": report.note as Any,
            "submitted_at": ISO8601DateFormatter().string(from: report.submittedAt),
        ]
        return try await post("/v1/reports", body: body, as: ReportSubmitResponse.self)
    }

    struct ReportSubmitResponse: Codable {
        let id: String
        let status: String
    }

    /// 1.2 UGC abuse-report channel. Posts a `type=objectionable_content`
    /// report referencing a camera pin the user wants flagged for human
    /// review. Used by `CameraDetailSheet`'s overflow menu. Distinct from
    /// the standard `submitReport` flow because there's no lat/lon, no
    /// photo, no type — just a free-text reason against an existing pin.
    func submitObjectionableContentReport(cameraId: String,
                                          reason: String) async throws -> ReportSubmitResponse {
        let body: [String: Any] = [
            "type": "objectionable_content",
            "camera_id": cameraId,
            "reason": reason,
            "submitted_at": ISO8601DateFormatter().string(from: Date()),
        ]
        return try await post("/v1/reports", body: body, as: ReportSubmitResponse.self)
    }

    // MARK: - Account

    func fetchSubscription(deviceToken: String?) async throws -> SubscriptionStatus {
        try await get("/v1/account/subscription", as: SubscriptionStatus.self,
                      headers: deviceToken.map { ["X-Device-Token": $0] } ?? [:])
    }

    struct SubscriptionStatus: Codable {
        let active: Bool
        let productId: String?
        let expiresAt: Date?

        enum CodingKeys: String, CodingKey {
            case active
            case productId = "product_id"
            case expiresAt = "expires_at"
        }
    }

    // MARK: - Private

    private func get<T: Decodable>(_ path: String, as: T.Type, headers: [String: String] = [:]) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        return try await perform(req)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any], as: T.Type) async throws -> T {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Strip nil values so `note: NSNull` doesn't ship.
        let cleaned = body.compactMapValues { v -> Any? in
            if v is NSNull { return nil }
            return v
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: cleaned)
        return try await perform(req)
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let urlError as URLError {
            if [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(urlError.code) {
                throw APIError.offline
            }
            throw APIError.unknown(urlError.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown("Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodeFailed(String(describing: error))
        }
    }
}
