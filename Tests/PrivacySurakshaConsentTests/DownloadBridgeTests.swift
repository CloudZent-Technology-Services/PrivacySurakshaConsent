import XCTest
@testable import PrivacySurakshaConsent

final class DownloadBridgeTests: XCTestCase {
    private let apiBase = URL(string: "https://api.example.test")!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testA2xxWritesTheBodyToAFileNamedFromTheFallback() async throws {
        let http = StubHTTP([.success(status: 200, body: Data("%PDF-1.4".utf8))])
        let bridge = DownloadBridge(apiBase: apiBase, appKey: nil, session: http, directory: tempDir)
        let outcome = await bridge.perform(
            DownloadSpec(id: "id1", method: "POST", path: "/api/v1/consent/receipt", body: nil, filename: "x.pdf")
        )
        guard case let .ok(fileURL, _) = outcome else { return XCTFail("expected .ok, got \(outcome)") }
        XCTAssertEqual(fileURL.lastPathComponent, "x.pdf")
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "%PDF-1.4")
    }

    func testAContentDispositionFilenameWinsOverTheFallback() async {
        let http = StubHTTP([
            .success(
                status: 200, body: Data("{}".utf8),
                headers: ["Content-Disposition": "attachment; filename=\"real-name.json\""]
            ),
        ])
        let bridge = DownloadBridge(apiBase: apiBase, appKey: nil, session: http, directory: tempDir)
        let outcome = await bridge.perform(
            DownloadSpec(id: "id1", method: "POST", path: "/api/v1/consent/export", body: nil, filename: "fallback.json")
        )
        guard case let .ok(fileURL, _) = outcome else { return XCTFail("expected .ok, got \(outcome)") }
        XCTAssertEqual(fileURL.lastPathComponent, "real-name.json")
    }

    func testANon2xxYieldsTheHttpFailureKindWithStatus() async {
        let http = StubHTTP([.success(status: 404, body: Data())])
        let bridge = DownloadBridge(apiBase: apiBase, appKey: nil, session: http, directory: tempDir)
        let outcome = await bridge.perform(
            DownloadSpec(id: "id1", method: "POST", path: "/x", body: nil, filename: "x.pdf")
        )
        guard case let .failure(kind, status) = outcome else { return XCTFail("expected .failure, got \(outcome)") }
        XCTAssertEqual(kind, "http")
        XCTAssertEqual(status, 404)
    }

    /// A transport failure is "network" — mirrors HTTPBridgeTests's equivalent.
    func testATransportFailureIsReportedAsNetwork() async {
        let http = StubHTTP(alwaysOffline: true)
        let bridge = DownloadBridge(apiBase: apiBase, appKey: nil, session: http, directory: tempDir)
        let outcome = await bridge.perform(
            DownloadSpec(id: "id1", method: "GET", path: "/api/v1/consent/receipt", body: nil, filename: "x.pdf")
        )
        guard case let .failure(kind, status) = outcome else { return XCTFail("expected .failure, got \(outcome)") }
        XCTAssertEqual(kind, "network")
        XCTAssertNil(status)
    }

    /// Same trust boundary as HTTPBridge: an absolute-URL path is refused
    /// before any request is attempted, so the app key never leaves the
    /// process and no request lands on `http.requests`.
    func testAnAbsoluteURLPathIsRejectedWithoutAttemptingARequest() async {
        let http = StubHTTP([.success(status: 200, body: Data())])
        let bridge = DownloadBridge(
            apiBase: apiBase, appKey: "app_0123456789abcdef0123456789abcdef", session: http, directory: tempDir
        )
        let outcome = await bridge.perform(
            DownloadSpec(id: "id1", method: "GET", path: "https://evil.example.com/x", body: nil, filename: "x.pdf")
        )
        XCTAssertTrue(http.requests.isEmpty, "no request may be attempted for a non-API-relative path")
        guard case let .failure(kind, status) = outcome else { return XCTFail("expected .failure, got \(outcome)") }
        XCTAssertEqual(kind, "http")
        XCTAssertNil(status)
    }

    func testSendsTheAppKeyHeaderWhenConfigured() async throws {
        let http = StubHTTP([.success(status: 200, body: Data())])
        let appKey = "app_0123456789abcdef0123456789abcdef"
        let bridge = DownloadBridge(apiBase: apiBase, appKey: appKey, session: http, directory: tempDir)
        _ = await bridge.perform(
            DownloadSpec(id: "id1", method: "GET", path: "/api/v1/consent/receipt", body: nil, filename: "x.pdf")
        )
        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: HTTPBridge.appKeyHeader), appKey)
    }
}
