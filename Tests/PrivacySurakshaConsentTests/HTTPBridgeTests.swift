import XCTest
@testable import PrivacySurakshaConsent

/// Row 384. The app key authenticates an Origin-less consent POST: a site that
/// has registered any app rejects one without a valid X-Compliant-App header
/// with 403. A site that has registered no apps is unaffected, which is why an
/// SDK integration can be tested before any registration exists.
final class HTTPBridgeTests: XCTestCase {

    private let apiBase = URL(string: "https://api.example.com")!
    private let appKey = "app_0123456789abcdef0123456789abcdef"

    private func spec(
        method: String = "POST", path: String = "/api/v1/consent", body: Data? = Data("{}".utf8)
    ) -> HTTPRequestSpec {
        HTTPRequestSpec(id: "req-1", method: method, path: path, body: body)
    }

    func testJoinsTheApiRelativePathOntoTheConfiguredBase() async throws {
        let http = StubHTTP([.success(status: 200, body: Data("{}".utf8))])
        _ = await HTTPBridge(apiBase: apiBase, appKey: nil, session: http).perform(spec())

        let url = try XCTUnwrap(http.requests.first?.url)
        XCTAssertEqual(url.absoluteString, "https://api.example.com/api/v1/consent")
    }

    func testSendsTheAppKeyHeaderWhenConfigured() async throws {
        let http = StubHTTP([.success(status: 200, body: Data("{}".utf8))])
        _ = await HTTPBridge(apiBase: apiBase, appKey: appKey, session: http).perform(spec())

        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Compliant-App"), appKey)
    }

    /// nil appKey sends NO header — the correct behaviour against a
    /// development site that has registered no apps.
    func testSendsNoHeaderWhenNoAppKeyIsConfigured() async throws {
        let http = StubHTTP([.success(status: 200, body: Data("{}".utf8))])
        _ = await HTTPBridge(apiBase: apiBase, appKey: nil, session: http).perform(spec())

        let request = try XCTUnwrap(http.requests.first)
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Compliant-App"))
    }

    /// Every bridged request carries it, not just the two enforced routes.
    /// Scoping to a hardcoded path list would mean four shells to edit the day
    /// a third route starts enforcing; an unnecessary header costs nothing.
    func testTheHeaderIsSentOnEveryRouteNotJustConsent() async throws {
        let http = StubHTTP([.success(status: 200, body: Data("{}".utf8))])
        let bridge = HTTPBridge(apiBase: apiBase, appKey: appKey, session: http)
        _ = await bridge.perform(spec(method: "GET", path: "/api/v1/something-else", body: nil))

        XCTAssertEqual(
            http.requests.first?.value(forHTTPHeaderField: "X-Compliant-App"), appKey
        )
    }

    func testSendsTheBodyAndContentTypeOnAPost() async throws {
        let http = StubHTTP([.success(status: 200, body: Data("{}".utf8))])
        let body = Data(#"{"siteKey":"sk"}"#.utf8)
        _ = await HTTPBridge(apiBase: apiBase, appKey: nil, session: http)
            .perform(spec(body: body))

        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.httpBody, body)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.httpMethod, "POST")
    }

    /// A GET never carries a body (EMBEDDED.md section 4).
    func testAGetCarriesNoBody() async throws {
        let http = StubHTTP([.success(status: 200, body: Data("{}".utf8))])
        _ = await HTTPBridge(apiBase: apiBase, appKey: nil, session: http)
            .perform(spec(method: "GET", path: "/api/v1/thing", body: nil))

        XCTAssertNil(http.requests.first?.httpBody)
    }

    func testASuccessfulResponseReturnsOkWithTheBody() async throws {
        let payload = Data(#"{"recordId":"rec_1"}"#.utf8)
        let bridge = HTTPBridge(
            apiBase: apiBase, appKey: nil,
            session: StubHTTP([.success(status: 200, body: payload)])
        )
        guard case .ok(let data) = await bridge.perform(spec()) else {
            return XCTFail("expected ok")
        }
        XCTAssertEqual(data, payload)
    }

    /// The page understands exactly two error strings. A non-2xx is "http".
    /// The status code itself rides along too — this is how the page (via
    /// declaration.ts) tells a 404 apart from a real failure.
    func testANon2xxIsReportedAsHttp() async {
        let bridge = HTTPBridge(
            apiBase: apiBase, appKey: nil,
            session: StubHTTP([.success(status: 403, body: Data("{}".utf8))])
        )
        guard case .failure(let kind, let status) = await bridge.perform(spec()) else {
            return XCTFail("expected failure")
        }
        XCTAssertEqual(kind, "http", "403 from row 384 enforcement is an http failure")
        XCTAssertEqual(status, 403)
    }

    /// A regression test for the status carried above: a 404 must be
    /// distinguishable from any other http failure, because the page treats
    /// "no cookie declaration published yet" (404) very differently from a
    /// real server error.
    func testA404CarriesItsStatusDistinctlyFromOtherHttpFailures() async {
        let bridge = HTTPBridge(
            apiBase: apiBase, appKey: nil,
            session: StubHTTP([.success(status: 404, body: Data("{}".utf8))])
        )
        guard case .failure(let kind, let status) = await bridge.perform(spec()) else {
            return XCTFail("expected failure")
        }
        XCTAssertEqual(kind, "http")
        XCTAssertEqual(status, 404)
    }

    // MARK: - The path is page-supplied, therefore untrusted

    /// protocol.ts documents `path` as "always absolute and API-relative".
    /// That is a document, not an invariant: URL(string:relativeTo:) honours
    /// an absolute URL by resolving to THAT host, and the request would carry
    /// row 384's X-Compliant-App header to it. The header must never leave
    /// apiBase's host.
    private func assertRejected(_ path: String, _ why: String) async {
        let http = StubHTTP([.success(status: 200, body: Data("{}".utf8))])
        let result = await HTTPBridge(apiBase: apiBase, appKey: appKey, session: http)
            .perform(spec(path: path))

        // The load-bearing assertion: no request was made AT ALL, so the app
        // key never left the process.
        XCTAssertTrue(
            http.requests.isEmpty,
            "\(why): no request may be attempted, got \(http.requests.compactMap(\.url))"
        )
        guard case .failure(let kind, let status) = result else {
            return XCTFail("\(why): expected a failure result")
        }
        // "http", not "network": this shell REFUSED the request — nothing
        // failed in transport, so the page must treat it as definitive.
        XCTAssertEqual(kind, "http", why)
        // No request was attempted, so there is no server status to carry.
        XCTAssertNil(status, why)
    }

    func testAnAbsoluteURLPathIsRejected() async {
        await assertRejected(
            "https://evil.example.com/api/v1/consent",
            "an absolute URL would replace apiBase's host outright"
        )
    }

    func testASchemeRelativePathIsRejected() async {
        await assertRejected(
            "//evil.example.com/api/v1/consent",
            "a scheme-relative path resolves to that host, keeping only apiBase's scheme"
        )
    }

    func testAPathWithNoLeadingSlashIsRejected() async {
        await assertRejected(
            "api/v1/consent", "a relative path is not the API-relative shape protocol.ts documents"
        )
    }

    /// The regression half: the legitimate case must still resolve onto
    /// apiBase. The tests at the top of this file cover it too; this one
    /// states it as the explicit counterpart to the three rejections.
    func testALegitimateApiRelativePathStillResolvesOntoApiBase() async throws {
        let http = StubHTTP([.success(status: 200, body: Data("{}".utf8))])
        let result = await HTTPBridge(apiBase: apiBase, appKey: appKey, session: http)
            .perform(spec(path: "/api/v1/consent"))

        let url = try XCTUnwrap(http.requests.first?.url)
        XCTAssertEqual(url.absoluteString, "https://api.example.com/api/v1/consent")
        guard case .ok = result else { return XCTFail("expected ok, got \(result)") }
    }

    /// A transport failure is "network".
    func testATransportFailureIsReportedAsNetwork() async {
        let bridge = HTTPBridge(
            apiBase: apiBase, appKey: nil, session: StubHTTP(alwaysOffline: true)
        )
        guard case .failure(let kind, let status) = await bridge.perform(spec()) else {
            return XCTFail("expected failure")
        }
        XCTAssertEqual(kind, "network")
        XCTAssertNil(status, "a transport failure never reached a server, so it carries no status")
    }
}
