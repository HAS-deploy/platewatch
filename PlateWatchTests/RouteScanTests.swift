import XCTest
import CoreLocation
import MapKit
@testable import PlateWatch

/// Route Scan — covers the new MKDirections + privacy-preferring route
/// mode added 2026-06-11. Test goals:
///
/// 1. `testAlprScoreCountsDistinctOnly` — a polyline that passes near the
///    SAME ALPR camera at two adjacent points must score that camera once.
/// 2. `testPrivacyRecommendedPicksLowestAlprAlternative` — given alpr counts
///    [5, 2, 8], the one with 2 is the privacy-recommended alternative.
/// 3. `testForbiddenWordsAbsentFromUserStrings` — string-scans the new
///    RouteScan files to defend against future copy regressions that would
///    trip a 4.2.6 / enforcement-evasion reviewer misread.
/// 4. `testFreeTierCannotPickPrivacyRoute` — non-entitled users that ask for
///    `.privacyPreferring` stay on `.fastest`.
@MainActor
final class RouteScanTests: XCTestCase {

    private func makeStore() -> CameraStore {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("platewatch-route-test-\(UUID().uuidString).json")
        return CameraStore(fileURL: tmp)
    }

    private func makeCamera(id: String,
                            lat: Double,
                            lon: Double,
                            type: CameraType = .alpr) -> Camera {
        Camera(
            id: id, lat: lat, lon: lon, type: type,
            subtype: nil, brand: nil, direction: nil,
            roadName: nil, city: nil, state: "CA", country: "US",
            source: "test", sourceUrl: nil,
            confidenceScore: 0.9, verifiedStatus: .verified,
            firstSeen: nil, lastSeen: nil, updatedAt: nil, tagsJson: nil
        )
    }

    // MARK: - Distinct-only scoring

    /// A polyline whose two adjacent points both pass within 50 m of the
    /// SAME ALPR camera should count that camera ONCE — not twice.
    func testAlprScoreCountsDistinctOnly() {
        let store = makeStore()
        // Single ALPR camera at the equator (longitude 0).
        store.upsert([
            makeCamera(id: "alpr-1", lat: 0.0, lon: 0.0, type: .alpr)
        ])
        // Polyline with three points laid east along the equator, all
        // within ~50 m of the camera.
        //   0.0001 deg ≈ 11.1 m → all three coordinates well under 50 m.
        let polyline: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 0.0, longitude: -0.0002),
            CLLocationCoordinate2D(latitude: 0.0, longitude:  0.0000),
            CLLocationCoordinate2D(latitude: 0.0, longitude:  0.0002),
        ]
        let service = RouteRiskService(store: store)
        let (alprCount, totalCount, byType) = service.countCamerasAlong(polyline: polyline)
        XCTAssertEqual(alprCount, 1, "Same ALPR camera near two adjacent points must count once")
        XCTAssertEqual(totalCount, 1)
        XCTAssertEqual(byType[.alpr], 1)
    }

    // MARK: - Privacy recommendation logic

    /// `RouteRiskService.privacyRecommendedFlags(forAlprCounts:)` must mark
    /// the alternative with the lowest ALPR count as recommended and leave
    /// all others as false.
    func testPrivacyRecommendedPicksLowestAlprAlternative() {
        let flags = RouteRiskService.privacyRecommendedFlags(forAlprCounts: [5, 2, 8])
        XCTAssertEqual(flags, [false, true, false])
        // Sanity: only one is true.
        XCTAssertEqual(flags.filter { $0 }.count, 1)
    }

    /// Ties break to the FIRST index seen so the picker is stable across
    /// the run.
    func testPrivacyRecommendedBreaksTiesByFirstIndex() {
        XCTAssertEqual(RouteRiskService.privacyRecommendedFlags(forAlprCounts: [3, 3, 3]),
                       [true, false, false])
        XCTAssertEqual(RouteRiskService.privacyRecommendedFlags(forAlprCounts: [5, 2, 2]),
                       [false, true, false])
    }

    func testPrivacyRecommendedHandlesEmptyInput() {
        XCTAssertEqual(RouteRiskService.privacyRecommendedFlags(forAlprCounts: []), [])
    }

    // MARK: - Free-tier mode gating

    /// Non-entitled users that ask for `.privacyPreferring` must stay on
    /// `.fastest`. The view layer presents the paywall as a side-effect
    /// (covered by the integration screenshot pipeline, not here).
    func testFreeTierCannotPickPrivacyRoute() {
        let suite = "test.platewatch.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let entitlement = UserEntitlement(defaults: defaults)
        // Backdate first launch so the install trial has already expired and
        // there's no premium flag set. Free tier.
        let longAgo = Date().addingTimeInterval(-30 * 86400)
        entitlement.recordFirstLaunchIfNeeded(now: longAgo)
        XCTAssertFalse(entitlement.isEntitled())

        let resolved = RouteScanModeGate.resolve(requested: .privacyPreferring,
                                                 entitlement: entitlement)
        XCTAssertEqual(resolved, .fastest)
    }

    /// Entitled users (premium OR inside trial) keep `.privacyPreferring`.
    func testEntitledUserKeepsPrivacyMode() {
        let suite = "test.platewatch.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let entitlement = UserEntitlement(defaults: defaults)
        entitlement.recordFirstLaunchIfNeeded()
        XCTAssertTrue(entitlement.isEntitled())

        let resolved = RouteScanModeGate.resolve(requested: .privacyPreferring,
                                                 entitlement: entitlement)
        XCTAssertEqual(resolved, .privacyPreferring)
    }

    // MARK: - Copy hygiene — defense against future regressions

    /// String-scan the new RouteScan source files for the forbidden words
    /// list locked in the risk profile §0 Privacy-preferring route mode
    /// section. If any of these appear, refactor the copy before shipping;
    /// they trip the 4.2.6 / enforcement-evasion reviewer misread that this
    /// whole feature is calibrated to avoid.
    func testForbiddenWordsAbsentFromUserStrings() throws {
        // Build the source tree path from the bundle's location → repo root.
        // The test bundle lives in DerivedData; we walk up to the repo root
        // by hopping the well-known relative offset isn't reliable, so we
        // ship a fallback: look up via env-var or default to a search list.
        let sourceFiles = try locateRouteScanSources()
        XCTAssertFalse(sourceFiles.isEmpty,
                       "Couldn't locate the RouteScan source files for the static scan")

        let forbidden = [
            "avoid", "evade", "beat", "bypass", "around", "skip",
            "ticket", "police", "officer", "detect", "law enforcement",
        ]
        for path in sourceFiles {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            // Strip comments so we don't false-positive on technical prose
            // (e.g. "the user makes the final pick" — the word "around"
            // never appears in our copy but does sometimes show up in
            // doc-comments describing geometry).
            let stripped = stripComments(from: content)
            // Only scan string literals to keep false-positives near zero.
            let literals = extractStringLiterals(from: stripped)
            for literal in literals {
                let lower = literal.lowercased()
                for word in forbidden {
                    XCTAssertFalse(
                        containsWord(lower, word: word),
                        "Forbidden word \"\(word)\" found in user-visible literal in \(path): \"\(literal)\""
                    )
                }
            }
        }
    }

    private func locateRouteScanSources() throws -> [String] {
        // Walk up from the test bundle to the project source root by
        // probing for the `PlateWatch/Features/RouteScan` directory. Works
        // from both DerivedData (Xcode) and `.build/` (SPM-style).
        let probe = "PlateWatch/Features/RouteScan"
        let fm = FileManager.default
        let candidates = [
            // 1. Compile-time #file path of the current test — most reliable.
            //    Walk up from `<repo>/PlateWatchTests/RouteScanTests.swift`.
            URL(fileURLWithPath: #file)
                .deletingLastPathComponent()      // PlateWatchTests
                .deletingLastPathComponent()      // <repo>
                .path,
            // 2. Bundle resource root fallback.
            Bundle(for: RouteScanTests.self).bundlePath,
        ]
        for c in candidates {
            let candidatePath = (c as NSString).appendingPathComponent(probe)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: candidatePath, isDirectory: &isDir), isDir.boolValue {
                let files = try fm.contentsOfDirectory(atPath: candidatePath)
                return files
                    .filter { $0.hasSuffix(".swift") }
                    .map { (candidatePath as NSString).appendingPathComponent($0) }
            }
        }
        return []
    }

    /// Crude single-pass C-style comment stripper. Handles `//` line comments
    /// and `/* ... */` block comments. Doesn't need to handle string-inside-
    /// comment edge cases because this is a static defense test, not a
    /// compiler.
    private func stripComments(from source: String) -> String {
        var out = ""
        var i = source.startIndex
        var inLineComment = false
        var inBlockComment = false
        while i < source.endIndex {
            let c = source[i]
            let next = source.index(after: i) < source.endIndex ? source[source.index(after: i)] : " "
            if inLineComment {
                if c == "\n" { inLineComment = false; out.append(c) }
            } else if inBlockComment {
                if c == "*" && next == "/" {
                    inBlockComment = false
                    i = source.index(after: i)
                }
            } else if c == "/" && next == "/" {
                inLineComment = true
                i = source.index(after: i)
            } else if c == "/" && next == "*" {
                inBlockComment = true
                i = source.index(after: i)
            } else {
                out.append(c)
            }
            i = source.index(after: i)
        }
        return out
    }

    /// Pull every double-quoted string literal out of a Swift source file.
    /// Naive but sufficient for our copy hygiene check — covers the only
    /// surface this test targets (user-facing strings).
    private func extractStringLiterals(from source: String) -> [String] {
        var literals: [String] = []
        var current = ""
        var inString = false
        var escape = false
        for c in source {
            if escape {
                current.append(c)
                escape = false
                continue
            }
            if c == "\\" && inString {
                escape = true
                continue
            }
            if c == "\"" {
                if inString {
                    literals.append(current)
                    current = ""
                    inString = false
                } else {
                    inString = true
                }
                continue
            }
            if inString {
                current.append(c)
            }
        }
        return literals
    }

    /// Whole-word match (case-insensitive caller). Avoids false-positives on
    /// substrings like "skipping" matching "skip" — we want the literal
    /// word. Uses Foundation's `\b` regex.
    private func containsWord(_ haystack: String, word: String) -> Bool {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: word) + "\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(haystack.startIndex..<haystack.endIndex, in: haystack)
        return regex.firstMatch(in: haystack, range: range) != nil
    }
}
