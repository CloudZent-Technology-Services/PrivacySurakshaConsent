import XCTest
@testable import PrivacySurakshaConsent

/// The durable copy of the visitor's decision. The page's own copy dies with
/// the WebView, so a failure to persist here loses the decision entirely
/// (EMBEDDED.md section 4, `persist`).
final class PrefsStoreTests: XCTestCase {

    private var suiteName: String!
    private var subject: PrefsStore!

    override func setUp() {
        super.setUp()
        suiteName = "com.compliant.tests.\(UUID().uuidString)"
        subject = PrefsStore(suiteName: suiteName)
    }

    override func tearDown() {
        subject.clear()
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testStartsEmpty() {
        XCTAssertNil(subject.prefs)
        XCTAssertNil(subject.lang)
    }

    func testRoundTripsBothFields() {
        let prefs = Data(#"{"v":1,"action":"accept_all"}"#.utf8)
        subject.write(prefs: prefs, lang: "hi")
        XCTAssertEqual(subject.prefs, prefs)
        XCTAssertEqual(subject.lang, "hi")
    }

    /// persist always sends BOTH fields, never a partial patch
    /// (EMBEDDED.md section 4). Writing nil for lang must clear it rather
    /// than leave the previous value in place.
    func testWritingNilLangClearsItRatherThanPreservingIt() {
        subject.write(prefs: Data("{}".utf8), lang: "ur")
        subject.write(prefs: Data("{}".utf8), lang: nil)
        XCTAssertNil(subject.lang)
    }

    /// prefs: null means clear the stored decision.
    func testWritingNilPrefsClearsTheDecision() {
        subject.write(prefs: Data("{}".utf8), lang: "en")
        subject.write(prefs: nil, lang: "en")
        XCTAssertNil(subject.prefs)
        XCTAssertEqual(subject.lang, "en", "clearing the decision must not clear the language")
    }

    func testSurvivesANewInstanceOverTheSameSuite() {
        subject.write(prefs: Data(#"{"v":1}"#.utf8), lang: "ta")
        let reopened = PrefsStore(suiteName: suiteName)
        XCTAssertEqual(reopened.prefs, Data(#"{"v":1}"#.utf8))
        XCTAssertEqual(reopened.lang, "ta")
    }
}
