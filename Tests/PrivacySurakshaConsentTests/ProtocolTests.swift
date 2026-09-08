import XCTest
@testable import PrivacySurakshaConsent

/// Mirrors packages/banner/src/embedded/protocol.ts. Every field name here is
/// copied from that file; if the two ever disagree, the .ts file is right.
final class ProtocolTests: XCTestCase {

    private let uuid = "4f8a2b1c-3d5e-4a7b-9c0d-1e2f3a4b5c6d"

    // MARK: - Host -> page

    func testInitCarriesSourceAndEveryRequiredField() throws {
        let msg = HostMessage.init_(
            siteKey: "sk_test",
            apiBase: "https://api.example.com",
            visitorId: uuid,
            config: Data(#"{"consentValidityDays":180}"#.utf8),
            prefs: nil,
            lang: nil
        )
        let object = try decodeToObject(msg)

        XCTAssertEqual(object["source"] as? String, "compliant-embedded")
        XCTAssertEqual(object["type"] as? String, "init")
        XCTAssertEqual(object["siteKey"] as? String, "sk_test")
        XCTAssertEqual(object["apiBase"] as? String, "https://api.example.com")
        XCTAssertEqual(object["visitorId"] as? String, uuid)
        XCTAssertNotNil(object["config"])
        // Present-and-null, not absent: the page reads `prefs` and `lang` as
        // "fresh install" only when they are explicitly null.
        XCTAssertTrue(object["prefs"] is NSNull)
        XCTAssertTrue(object["lang"] is NSNull)
    }

    /// config and prefs are opaque JSON (design 3.4) — they must be embedded
    /// as live JSON, never re-encoded as a string. A string here would make
    /// the page's `message.config.consentValidityDays` undefined.
    func testConfigIsEmbeddedAsJSONNotAsAString() throws {
        let msg = HostMessage.init_(
            siteKey: "sk", apiBase: "https://a.example", visitorId: uuid,
            config: Data(#"{"consentValidityDays":180,"purposes":[]}"#.utf8),
            prefs: nil, lang: nil
        )
        let object = try decodeToObject(msg)
        let config = try XCTUnwrap(object["config"] as? [String: Any])
        XCTAssertEqual(config["consentValidityDays"] as? Int, 180)
    }

    func testViewMessageUsesTheWireValueForAgeGate() throws {
        let object = try decodeToObject(HostMessage.view(.ageGate))
        XCTAssertEqual(object["type"] as? String, "view")
        XCTAssertEqual(object["view"] as? String, "age_gate")
    }

    func testCatalogMessageCarriesANullCatalogWhenTheShellHasNoFile() throws {
        let object = try decodeToObject(HostMessage.catalog(lang: "xx", catalog: nil))
        XCTAssertEqual(object["lang"] as? String, "xx")
        XCTAssertTrue(object["catalog"] is NSNull)
    }

    // MARK: - Ledger row 398: a corrupt store must not read as a fresh install

    /// `prefs: nil` means "no stored decision" and NSNull is right for it.
    /// Bytes that are present but unparseable mean something completely
    /// different — the store is corrupt — and sending NSNull for those tells
    /// the page the visitor never answered. It re-prompts, `persist`
    /// overwrites, and the original decision is gone. Nothing reaches
    /// `onError`, because a swallowed `try?` had already decided this was fine.
    ///
    /// Throwing hands it to `WebViewHost.send`, which reports it and delivers
    /// nothing — the shell shows no notice rather than a wrong one, which is
    /// the same fail-closed rule as rule 5.
    func testCorruptPrefsThrowsRatherThanSendingNull() {
        let msg = HostMessage.init_(
            siteKey: "sk", apiBase: "https://a.example", visitorId: uuid,
            config: Data(#"{"consentValidityDays":180}"#.utf8),
            prefs: Data("{not json".utf8),
            lang: "en"
        )
        XCTAssertThrowsError(try msg.jsonString(), "corrupt prefs must not serialise to null")
    }

    /// Same swallow, lower stakes and still wrong: `catalog: nil` legitimately
    /// means "no file bundled for this locale, keep rendering English", so a
    /// corrupt catalog silently becomes "no translation" and a Hindi visitor
    /// reads an English notice with nothing logged anywhere.
    func testCorruptCatalogThrowsRatherThanSendingNull() {
        let msg = HostMessage.catalog(lang: "hi", catalog: Data("{not json".utf8))
        XCTAssertThrowsError(try msg.jsonString(), "a corrupt catalog must not serialise to null")
    }

    /// The guard rail on the two above: valid bytes must still go through, and
    /// a genuine nil must still become NSNull. Without this, "throw on
    /// everything" would pass both tests above.
    func testValidPrefsAndCatalogStillSerialiseNormally() throws {
        let withPrefs = try decodeToObject(
            HostMessage.init_(
                siteKey: "sk", apiBase: "https://a.example", visitorId: uuid,
                config: Data(#"{"consentValidityDays":180}"#.utf8),
                prefs: Data(#"{"v":1,"action":"accept_all"}"#.utf8),
                lang: "hi"
            )
        )
        let prefs = try XCTUnwrap(withPrefs["prefs"] as? [String: Any])
        XCTAssertEqual(prefs["action"] as? String, "accept_all")

        let withCatalog = try decodeToObject(
            HostMessage.catalog(lang: "hi", catalog: Data(#"{"banner.title":"शीर्षक"}"#.utf8))
        )
        let catalog = try XCTUnwrap(withCatalog["catalog"] as? [String: Any])
        XCTAssertEqual(catalog["banner.title"] as? String, "शीर्षक")
    }

    /// NOT part of row 398, asserted so a later reader does not "fix" it to
    /// match the two above. A 2xx whose body is not JSON is still a SUCCESS —
    /// the page reads `data` and ignores what it cannot use — and throwing
    /// here would turn a working request into no reply at all.
    func testANonJSONHttpResultBodyStaysASuccess() throws {
        let object = try decodeToObject(
            HostMessage.httpResult(id: "r1", result: .ok(Data("plain text".utf8)))
        )
        let result = try XCTUnwrap(object["result"] as? [String: Any])
        XCTAssertEqual(result["ok"] as? Bool, true)
        XCTAssertTrue(result["data"] is NSNull)
    }

    func testHttpResultOkAndFailureShapes() throws {
        let ok = try decodeToObject(
            HostMessage.httpResult(id: "r1", result: .ok(Data(#"{"recordId":"abc"}"#.utf8)))
        )
        let okResult = try XCTUnwrap(ok["result"] as? [String: Any])
        XCTAssertEqual(okResult["ok"] as? Bool, true)
        XCTAssertNotNil(okResult["data"])

        let bad = try decodeToObject(
            HostMessage.httpResult(id: "r2", result: .failure("network"))
        )
        let badResult = try XCTUnwrap(bad["result"] as? [String: Any])
        XCTAssertEqual(badResult["ok"] as? Bool, false)
        XCTAssertEqual(badResult["error"] as? String, "network")
    }

    // MARK: - Page -> host

    func testDecodesReadyAndPainted() throws {
        guard case .ready(let ms) = try PageEvent.decode(#"{"type":"ready","timeToReadyMs":12.5}"#)
        else { return XCTFail("expected ready") }
        XCTAssertEqual(ms, 12.5, accuracy: 0.001)

        guard case .painted(let p) = try PageEvent.decode(#"{"type":"painted","timeToPaintMs":40}"#)
        else { return XCTFail("expected painted") }
        XCTAssertEqual(p, 40, accuracy: 0.001)
    }

    /// persist sends both fields together, never a partial patch
    /// (EMBEDDED.md section 4). prefs: null means clear the stored decision.
    func testDecodesPersistWithBothFieldsIncludingNulls() throws {
        guard case .persist(let prefs, let lang) =
            try PageEvent.decode(#"{"type":"persist","prefs":null,"lang":null}"#)
        else { return XCTFail("expected persist") }
        XCTAssertNil(prefs)
        XCTAssertNil(lang)

        guard case .persist(let prefs2, let lang2) = try PageEvent.decode(
            #"{"type":"persist","prefs":{"v":1,"action":"accept_all"},"lang":"hi"}"#
        ) else { return XCTFail("expected persist") }
        XCTAssertNotNil(prefs2)
        XCTAssertEqual(lang2, "hi")
    }

    func testDecodesDecisionWithSignals() throws {
        let raw = #"""
        {"type":"decision","prefs":{"v":1,"action":"accept_all"},
         "signals":{"ad_storage":"granted","analytics_storage":"denied"}}
        """#
        guard case .decision(_, let signals) = try PageEvent.decode(raw)
        else { return XCTFail("expected decision") }
        XCTAssertEqual(signals["ad_storage"], .granted)
        XCTAssertEqual(signals["analytics_storage"], .denied)
    }

    func testDecodesViewChangedIncludingHidden() throws {
        guard case .viewChanged(let v) =
            try PageEvent.decode(#"{"type":"viewChanged","view":"hidden"}"#)
        else { return XCTFail("expected viewChanged") }
        XCTAssertEqual(v, .hidden)
    }

    func testDecodesCatalogRequestAndHttpRequest() throws {
        guard case .catalogRequest(let lang) =
            try PageEvent.decode(#"{"type":"catalogRequest","lang":"ur"}"#)
        else { return XCTFail("expected catalogRequest") }
        XCTAssertEqual(lang, "ur")

        let raw = #"{"type":"httpRequest","id":"x1","method":"POST","path":"/api/v1/consent","body":{"a":1}}"#
        guard case .httpRequest(let spec) = try PageEvent.decode(raw)
        else { return XCTFail("expected httpRequest") }
        XCTAssertEqual(spec.id, "x1")
        XCTAssertEqual(spec.method, "POST")
        XCTAssertEqual(spec.path, "/api/v1/consent")
        XCTAssertNotNil(spec.body)
    }

    /// A GET never carries a body (EMBEDDED.md section 4).
    func testHttpRequestBodyIsNilWhenAbsent() throws {
        let raw = #"{"type":"httpRequest","id":"g1","method":"GET","path":"/api/v1/thing"}"#
        guard case .httpRequest(let spec) = try PageEvent.decode(raw)
        else { return XCTFail("expected httpRequest") }
        XCTAssertNil(spec.body)
    }

    func testDecodesError() throws {
        guard case .error(let message) =
            try PageEvent.decode(#"{"type":"error","message":"boom"}"#)
        else { return XCTFail("expected error") }
        XCTAssertEqual(message, "boom")
    }

    func testRejectsAnUnknownEventType() {
        XCTAssertThrowsError(try PageEvent.decode(#"{"type":"nope"}"#))
    }

    func testRejectsMalformedJSON() {
        XCTAssertThrowsError(try PageEvent.decode("not json"))
    }

    // MARK: - Helper

    private func decodeToObject(_ message: HostMessage) throws -> [String: Any] {
        let json = try message.jsonString()
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try XCTUnwrap(object as? [String: Any])
    }
}
