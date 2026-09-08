import XCTest
@testable import PrivacySurakshaConsent

/// Job 1 (design 3.2 / EMBEDDED.md section 3): decide whether consent is
/// needed WITHOUT creating a WebView. That forces this one duplication of
/// web-core logic — see design 4.4, "the named exception".
///
/// The cases come from packages/banner/fixtures/renewal-cases.json, the same
/// file packages/banner/src/renewal.test.ts runs. Do not add cases here that
/// are not in the fixture: a case that only exists on one platform is exactly
/// the drift this arrangement exists to prevent.
final class ConsentGateTests: XCTestCase {

    private struct Fixture: Decodable {
        struct Expiry: Decodable {
            let name: String, at: String, validityDays: Int, expired: Bool
        }
        struct Purpose: Decodable { let id: String; let materialSince: String? }
        struct Drift: Decodable {
            let name: String, at: String
            let atServer: String?
            let purposes: [Purpose], drifted: [String]
        }
        let now: String
        let expiry: [Expiry]
        let drift: [Drift]
    }

    private func loadFixture() throws -> Fixture {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "Resources/renewal-cases.json", withExtension: nil),
            "fixture missing — run scripts/sync-ios-assets.mjs"
        )
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    private func date(_ iso: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return try XCTUnwrap(formatter.date(from: iso), "unparseable timestamp \(iso)")
    }

    func testEveryExpiryCaseInTheSharedFixture() throws {
        let fixture = try loadFixture()
        let now = try date(fixture.now)
        XCTAssertFalse(fixture.expiry.isEmpty, "fixture has no expiry cases")

        for c in fixture.expiry {
            XCTAssertEqual(
                ConsentGate.isExpired(
                    savedAt: c.at, atServer: nil, validityDays: c.validityDays, now: now
                ),
                c.expired,
                "expiry case: \(c.name)"
            )
        }
    }

    func testEveryDriftCaseInTheSharedFixture() throws {
        let fixture = try loadFixture()
        XCTAssertFalse(fixture.drift.isEmpty, "fixture has no drift cases")

        for c in fixture.drift {
            let purposes: [[String: Any]] = c.purposes.map { p in
                var dict: [String: Any] = ["id": p.id]
                if let since = p.materialSince { dict["materialSince"] = since }
                return dict
            }
            XCTAssertEqual(
                ConsentGate.driftedPurposeIds(
                    savedAt: c.at, atServer: c.atServer, purposes: purposes
                ),
                c.drifted,
                "drift case: \(c.name)"
            )
        }
    }

    // MARK: - decide()

    private let config = Data(#"""
    {"consentValidityDays":180,"purposes":[{"id":"a","materialSince":"2026-03-01T00:00:00.000Z"}]}
    """#.utf8)

    func testNoStoredDecisionNeedsConsent() throws {
        let result = ConsentGate.decide(prefs: nil, config: config, now: try date("2026-08-03T00:00:00.000Z"))
        XCTAssertEqual(result, .needed(reason: .noDecision))
    }

    func testAFreshUndriftedDecisionDoesNotNeedConsent() throws {
        let prefs = Data(#"{"v":1,"action":"accept_all","at":"2026-07-01T00:00:00.000Z"}"#.utf8)
        let result = ConsentGate.decide(prefs: prefs, config: config, now: try date("2026-08-03T00:00:00.000Z"))
        XCTAssertEqual(result, .notNeeded)
    }

    func testAnExpiredDecisionNeedsConsent() throws {
        let prefs = Data(#"{"v":1,"action":"accept_all","at":"2025-01-01T00:00:00.000Z"}"#.utf8)
        let result = ConsentGate.decide(prefs: prefs, config: config, now: try date("2026-08-03T00:00:00.000Z"))
        XCTAssertEqual(result, .needed(reason: .expired))
    }

    // NOTE: the brief's original fixture for this case used at:"2026-02-01",
    // which is actually 183 days before now:"2026-08-03" — past the config's
    // consentValidityDays:180, so ConsentGate.decide correctly reports
    // .expired (expiry wins over drift, per testExpiryIsReportedInPreferenceToDrift
    // below). That was a self-contradictory example in the brief, not a bug in
    // ConsentGate: verified independently against renewal.ts's isExpired via
    // the shared fixture (packages/banner/fixtures/renewal-cases.json), whose
    // "exactly at the boundary" case fixes the 180-day cutover at 2026-02-04.
    // Moved `at` to 2026-02-15 — 169 days before now (not expired) and still
    // before materialSince 2026-03-01 (still drifted) — to isolate drift from
    // expiry as the test's docstring intends.
    func testADriftedDecisionNeedsConsent() throws {
        let prefs = Data(#"{"v":1,"action":"accept_all","at":"2026-02-15T00:00:00.000Z"}"#.utf8)
        let result = ConsentGate.decide(prefs: prefs, config: config, now: try date("2026-08-03T00:00:00.000Z"))
        XCTAssertEqual(result, .needed(reason: .drifted))
    }

    /// Expiry wins over drift. embedded.ts:110 evaluates drift only when not
    /// expired — an expired decision is already being re-prompted from scratch,
    /// so drift on top of it is dead work.
    func testExpiryIsReportedInPreferenceToDrift() throws {
        let prefs = Data(#"{"v":1,"action":"accept_all","at":"2025-01-01T00:00:00.000Z"}"#.utf8)
        let result = ConsentGate.decide(prefs: prefs, config: config, now: try date("2026-08-03T00:00:00.000Z"))
        XCTAssertEqual(result, .needed(reason: .expired))
    }

    /// A malformed stored decision must not be treated as a valid one.
    func testUnparseablePrefsNeedsConsent() throws {
        let result = ConsentGate.decide(
            prefs: Data("not json".utf8), config: config,
            now: try date("2026-08-03T00:00:00.000Z")
        )
        XCTAssertEqual(result, .needed(reason: .noDecision))
    }

    /// A config with no consentValidityDays fails closed rather than treating
    /// the absence as "never expires".
    func testMissingValidityDaysFailsClosed() throws {
        let prefs = Data(#"{"v":1,"action":"accept_all","at":"2026-08-01T00:00:00.000Z"}"#.utf8)
        let result = ConsentGate.decide(
            prefs: prefs, config: Data("{}".utf8),
            now: try date("2026-08-03T00:00:00.000Z")
        )
        XCTAssertEqual(result, .needed(reason: .expired))
    }
}
