import XCTest
@testable import PrivacySurakshaConsent

/// JOB 4 — apply the `signals` object the page already computed.
///
/// The shell must NOT re-derive signals from granted categories. EMBEDDED.md
/// section 3 job 4 forbids it explicitly, so that four shells do not carry
/// four drifting copies of consentSignals() from
/// packages/banner/src/consent-mode.ts.
final class SignalWriterTests: XCTestCase {

    private final class SpyWriter: ConsentSignalWriter {
        private(set) var received: [[String: ConsentSignalState]] = []
        var errorToThrow: Error?
        func write(_ signals: [String: ConsentSignalState]) throws {
            received.append(signals)
            if let errorToThrow { throw errorToThrow }
        }
    }

    /// The seven keys consentSignals() in consent-mode.ts can emit. Copied
    /// from that file: security_storage plus the functional pair, analytics,
    /// and the three marketing keys.
    func testTheSevenConsentModeKeysAreDeclared() {
        XCTAssertEqual(Set(ConsentModeKey.all), Set([
            "ad_storage",
            "analytics_storage",
            "ad_user_data",
            "ad_personalization",
            "security_storage",
            "functionality_storage",
            "personalization_storage",
        ]))
    }

    /// Every known key is present after normalisation, defaulting to denied.
    /// A key the page omitted must not be read by the customer's adapter as
    /// "granted" through an accidental nil-coalesce on their side.
    func testNormalisationFillsAbsentKeysWithDenied() {
        let normalised = ConsentModeMapping.normalise(["ad_storage": .granted])
        XCTAssertEqual(normalised["ad_storage"], .granted)
        XCTAssertEqual(normalised["analytics_storage"], .denied)
        XCTAssertEqual(normalised.count, ConsentModeKey.all.count)
    }

    func testNormalisationPreservesEveryStateThePageSent() {
        let normalised = ConsentModeMapping.normalise([
            "ad_storage": .denied,
            "analytics_storage": .granted,
            "security_storage": .granted,
        ])
        XCTAssertEqual(normalised["ad_storage"], .denied)
        XCTAssertEqual(normalised["analytics_storage"], .granted)
        XCTAssertEqual(normalised["security_storage"], .granted)
    }

    /// An unrecognised key is dropped rather than forwarded. The customer's
    /// adapter maps keys to a fixed Firebase enum, so an unknown key would be
    /// a crash or a silent no-op depending on how they wrote it.
    func testNormalisationDropsUnknownKeys() {
        let normalised = ConsentModeMapping.normalise([
            "ad_storage": .granted,
            "invented_key": .granted,
        ])
        XCTAssertNil(normalised["invented_key"])
    }

    func testTheWriterReceivesTheNormalisedSignals() throws {
        let spy = SpyWriter()
        try spy.write(ConsentModeMapping.normalise(["analytics_storage": .granted]))
        XCTAssertEqual(spy.received.count, 1)
        XCTAssertEqual(spy.received.first?["analytics_storage"], .granted)
    }

    /// A throwing writer must not be allowed to cost the consent record.
    /// The record is the legally meaningful artefact and `persist` has already
    /// committed it by the time `decision` is sent (parent design 7).
    func testAThrowingWriterIsSurvivable() {
        let spy = SpyWriter()
        spy.errorToThrow = NSError(domain: "test", code: 1)
        XCTAssertThrowsError(try spy.write([:]), "the protocol is throwing; the caller swallows")
    }
}
