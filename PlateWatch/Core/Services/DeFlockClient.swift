import Foundation

/// Fetches real camera nodes from DeFlock's public Overpass endpoint. Used
/// once on first successful location fix to seed the local `CameraStore`
/// with actual pins around the user's area (the bundled seed dataset is
/// national-thin and reviewer-focused; real usage needs live coverage).
///
/// The endpoint is DeFlock's mirror of OSM's `enforcement` + `man_made=
/// surveillance` nodes. Data license: ODbL (OpenStreetMap).
actor DeFlockClient {
    private let endpoint = URL(string: "https://overpass.deflock.org/api/interpreter")!

    struct OverpassResponse: Decodable {
        struct Element: Decodable {
            let type: String
            let id: Int
            let lat: Double?
            let lon: Double?
            let tags: [String: String]?
        }
        let elements: [Element]
    }

    /// Fetch cameras inside a `radiusMeters` bbox around the given point.
    /// Returns an empty array on error or empty match; caller should tolerate
    /// silent failure.
    func fetchNearby(lat: Double, lon: Double, radiusMeters: Double) async throws -> [Camera] {
        let dLat = radiusMeters / 111_000
        let dLon = radiusMeters / (111_000 * max(cos(lat * .pi / 180), 0.01))
        let south = lat - dLat
        let north = lat + dLat
        let west = lon - dLon
        let east = lon + dLon
        let bbox = String(format: "%.5f,%.5f,%.5f,%.5f", south, west, north, east)

        let query = """
        [out:json][timeout:25];
        (
          node["man_made"="surveillance"](\(bbox));
          node["highway"="speed_camera"](\(bbox));
          node["enforcement"](\(bbox));
        );
        out body 2000;
        """

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("PlateAware/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 30
        let form = "data=" + (query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        req.httpBody = form.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)
        let now = Date()

        return decoded.elements.compactMap { el -> Camera? in
            guard let elLat = el.lat, let elLon = el.lon else { return nil }
            let tags = el.tags ?? [:]
            return Camera(
                id: "deflock-\(el.id)",
                lat: elLat,
                lon: elLon,
                type: Self.classify(tags: tags),
                subtype: tags["surveillance:type"] ?? tags["enforcement"],
                brand: tags["operator"] ?? tags["brand"],
                direction: tags["camera:direction"] ?? tags["direction"],
                roadName: tags["addr:street"],
                city: tags["addr:city"],
                state: tags["addr:state"],
                country: "US",
                source: "deflock",
                sourceUrl: "https://maps.deflock.org/node/\(el.id)",
                confidenceScore: nil,
                verifiedStatus: tags["surveillance:type"]?.lowercased() == "alpr" ? .verified : .unverified,
                firstSeen: nil,
                lastSeen: nil,
                updatedAt: now,
                tagsJson: nil
            )
        }
    }

    private static func classify(tags: [String: String]) -> CameraType {
        let survType = tags["surveillance:type"]?.lowercased() ?? ""
        let enforcement = tags["enforcement"]?.lowercased() ?? ""
        let highway = tags["highway"]?.lowercased() ?? ""
        if survType == "alpr" { return .alpr }
        if highway == "speed_camera" || enforcement.contains("maxspeed") { return .speed }
        if enforcement == "traffic_signals" || enforcement.contains("red_light") { return .redLight }
        if enforcement.contains("toll") { return .toll }
        if tags["surveillance:zone"]?.lowercased() == "school" { return .schoolZone }
        if tags["man_made"] == "surveillance" { return .other }
        return .traffic
    }
}
