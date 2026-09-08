import XCTest
import WebKit
@testable import PrivacySurakshaConsent

/// Page->host decode failures.
///
/// `PageEvent.decode` is hand-maintained against protocol.ts, so it CAN drift
/// from it. Both silent returns here used to make that drift undetectable:
/// a recognised message type the shell could no longer decode simply
/// disappeared, with no diagnostic anywhere in the SDK. One of the three
/// outcomes must still be silent, and these tests pin down which.
final class BridgeTests: XCTestCase {

    /// `WKScriptMessage` has no usable initialiser, so the body is supplied by
    /// override. Only `body` is read by the handler under test.
    private final class StubScriptMessage: WKScriptMessage {
        private let stubBody: Any
        init(_ body: Any) {
            self.stubBody = body
            super.init()
        }
        override var body: Any { stubBody }
    }

    private func errors(from raw: Any) -> [String] {
        var messages: [String] = []
        let bridge = Bridge(onEvent: { event in
            if case .error(let text) = event { messages.append(text) }
        })
        bridge.userContentController(
            WKUserContentController(), didReceive: StubScriptMessage(raw)
        )
        return messages
    }

    private func events(from raw: Any) -> [PageEvent] {
        var events: [PageEvent] = []
        let bridge = Bridge(onEvent: { events.append($0) })
        bridge.userContentController(
            WKUserContentController(), didReceive: StubScriptMessage(raw)
        )
        return events
    }

    /// The happy path, asserted so the failure cases below cannot pass
    /// vacuously against a bridge that reports everything.
    func testAWellFormedMessageIsDecodedAndForwarded() throws {
        let decoded = events(from: #"{"type":"viewChanged","view":"banner"}"#)
        XCTAssertEqual(decoded.count, 1)
        guard case .viewChanged(let view) = try XCTUnwrap(decoded.first) else {
            return XCTFail("expected viewChanged, got \(decoded)")
        }
        XCTAssertEqual(view, .banner)
    }

    /// A RECOGNISED type missing a field it requires. `prefs` is optional on
    /// `persist` but REQUIRED on `decision`, so this is a genuine contract
    /// violation rather than a tolerated absence — the shell's decoder and the
    /// page's protocol have drifted, or the page sent something broken.
    func testARecognisedTypeMissingARequiredFieldIsReported() {
        let messages = errors(from: #"{"type":"decision","signals":{"analytics":"granted"}}"#)
        XCTAssertEqual(messages.count, 1, "a decode failure must report exactly once")
        // The field name is asserted, not just the case: a report that does
        // not say WHICH field is missing cannot be acted on.
        XCTAssertTrue(
            messages.first?.contains("prefs") ?? false,
            "the report must name the missing field: \(messages)"
        )
    }

    func testAMalformedBodyIsReported() {
        let messages = errors(from: "not json at all")
        XCTAssertEqual(messages.count, 1)
        XCTAssertTrue(
            messages.first?.contains("malformed") ?? false,
            "the report must name the cause: \(messages)"
        )
    }

    /// JSON with no `type` is the same malformedJSON case — decode cannot even
    /// tell which message it was looking at.
    func testJSONWithNoTypeIsReported() {
        XCTAssertEqual(errors(from: #"{"view":"banner"}"#).count, 1)
    }

    /// THE ONE CORRECT SILENCE. An unrecognised type is a newer bundle posting
    /// a forward-compatible extension, not an error, and reporting it would
    /// turn every future protocol addition into noise in the customer's
    /// onError.
    func testAnUnknownEventTypeIsSilent() {
        let decoded = events(from: #"{"type":"somethingTheNextBundleAdds","x":1}"#)
        XCTAssertTrue(decoded.isEmpty, "an unknown type must produce no event at all: \(decoded)")
    }

    /// A non-string body is structurally not a page message — postToHost
    /// always stringifies — so there is no decode failure to report.
    func testANonStringBodyIsSilent() {
        let decoded = events(from: ["type": "viewChanged"])
        XCTAssertTrue(decoded.isEmpty, "a non-string body must stay silent: \(decoded)")
    }
}
