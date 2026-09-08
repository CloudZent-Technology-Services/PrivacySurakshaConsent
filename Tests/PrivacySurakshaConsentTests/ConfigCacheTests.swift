import XCTest
@testable import PrivacySurakshaConsent

/// Parent design 3.5's five rules. Rule 5 is the one that matters most and is
/// easiest to get wrong: no cache and no network means show NOTHING, not a
/// default notice. An app with no notice available must process nothing
/// non-essential, which is the same state as "no consent".
final class ConfigCacheTests: XCTestCase {

    private var directory: URL!
    private let apiBase = URL(string: "https://api.example.com")!
    private let liveConfig = Data(#"{"consentValidityDays":180,"purposes":[]}"#.utf8)

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func makeCache(_ http: StubHTTP) -> ConfigCache {
        ConfigCache(siteKey: "sk_test", apiBase: apiBase, session: http, directory: directory)
    }

    /// Rule 1 — fetch on start.
    func testFetchesFromTheCorrectEndpoint() async throws {
        let http = StubHTTP([.success(status: 200, body: liveConfig)])
        _ = await makeCache(http).load()

        let url = try XCTUnwrap(http.requests.first?.url)
        XCTAssertEqual(url.path, "/api/v1/config/sk_test")
        XCTAssertEqual(url.host, "api.example.com")
    }

    /// Rules 1 and 2 — fetch, then write to disk.
    func testASuccessfulFetchIsReturnedAndCached() async throws {
        let http = StubHTTP([.success(status: 200, body: liveConfig)])
        let cache = makeCache(http)

        let (config, error) = await cache.load()
        XCTAssertEqual(config, liveConfig)
        XCTAssertNil(error)
        XCTAssertEqual(cache.cached(), liveConfig, "rule 2: the response must be written to disk")
    }

    /// Rule 4 — network fails, cache exists, use the cache.
    func testFallsBackToTheCacheWhenTheNetworkFails() async throws {
        let warm = makeCache(StubHTTP([.success(status: 200, body: liveConfig)]))
        _ = await warm.load()

        let offline = makeCache(StubHTTP(alwaysOffline: true))
        let (config, error) = await offline.load()
        XCTAssertEqual(config, liveConfig)
        XCTAssertNil(error, "a cache hit is not an error the customer needs to see")
    }

    /// Rule 5 — network fails, NO cache. Show nothing, record nothing.
    func testNoCacheAndNoNetworkReturnsNothingAndReportsIt() async throws {
        let (config, error) = await makeCache(StubHTTP(alwaysOffline: true)).load()
        XCTAssertNil(config, "rule 5: never invent a notice")
        XCTAssertNotNil(error, "the customer must be able to log this")
    }

    /// A non-2xx is a failure, not a config. A 404 body is an error payload and
    /// rendering it as a notice would be worse than rendering nothing.
    ///
    /// Task 5 review: the server DID answer here, so the error reported must
    /// be distinguishable from a genuine network outage — collapsing both
    /// into the same case would mislead anyone debugging a live incident
    /// where the server is up but returning a bad status.
    func testANon2xxStatusIsTreatedAsAFailure() async throws {
        let http = StubHTTP([.success(status: 404, body: Data(#"{"error":"not found"}"#.utf8))])
        let (config, error) = await makeCache(http).load()
        XCTAssertNil(config)
        guard case .badStatus(404) = error as? ConfigCacheError else {
            return XCTFail("expected .badStatus(404), got \(String(describing: error))")
        }
    }

    /// A 200 carrying a body that is not JSON must not be cached — a later
    /// launch would then read garbage from disk and trust it. Same
    /// distinguishability requirement as the non-2xx case above.
    func testAMalformedBodyIsNotCached() async throws {
        let cache = makeCache(StubHTTP([.success(status: 200, body: Data("not json".utf8))]))
        let (config, error) = await cache.load()
        XCTAssertNil(config)
        guard case .malformedBody = error as? ConfigCacheError else {
            return XCTFail("expected .malformedBody, got \(String(describing: error))")
        }
        XCTAssertNil(cache.cached())
    }

    /// A genuine transport failure (no response at all) is the only case that
    /// should report .noCacheAndNoNetwork — distinct from the two cases above,
    /// where a response came back but was unusable.
    func testAGenuineNetworkFailureReportsNoCacheAndNoNetwork() async throws {
        let (config, error) = await makeCache(StubHTTP(alwaysOffline: true)).load()
        XCTAssertNil(config)
        guard case .noCacheAndNoNetwork = error as? ConfigCacheError else {
            return XCTFail("expected .noCacheAndNoNetwork, got \(String(describing: error))")
        }
    }

    /// Rule 3 — a later launch reads disk first. Proven by the cache being
    /// readable with no load() call at all.
    func testCachedIsReadableWithoutAFetch() async throws {
        _ = await makeCache(StubHTTP([.success(status: 200, body: liveConfig)])).load()
        let reopened = makeCache(StubHTTP(alwaysOffline: true))
        XCTAssertEqual(reopened.cached(), liveConfig)
    }

    /// A corrupt file on disk is a cache MISS, not a config.
    ///
    /// `fetch()` guarding the write is not enough on its own: a file
    /// truncated by a crash mid-write is read back by `cached()` and would be
    /// trusted. It then reaches `init` as bytes HostMessage.jsonString cannot
    /// serialise, and the page never receives `init` at all. Returning nil
    /// drops start() onto the awaited network path, where rules 4 and 5 apply.
    func testACorruptCacheFileIsTreatedAsACacheMiss() async throws {
        let cache = makeCache(StubHTTP([.success(status: 200, body: liveConfig)]))
        _ = await cache.load()
        XCTAssertEqual(cache.cached(), liveConfig, "test setup must start from a warm cache")

        // Written straight to the cache path, the way a crash or a corrupted
        // filesystem would leave it — not through any API of the class.
        let onDisk = directory.appendingPathComponent("config-sk_test.json")
        try Data("{\"consentValidi".utf8).write(to: onDisk, options: .atomic)

        XCTAssertNil(cache.cached(), "invalid JSON on disk must read back as no cache at all")
    }

    /// Two sites must not share one cache file.
    func testTheCacheIsKeyedBySiteKey() async throws {
        _ = await ConfigCache(siteKey: "sk_a", apiBase: apiBase,
                              session: StubHTTP([.success(status: 200, body: liveConfig)]),
                              directory: directory).load()
        let other = ConfigCache(siteKey: "sk_b", apiBase: apiBase,
                                session: StubHTTP(alwaysOffline: true), directory: directory)
        XCTAssertNil(other.cached())
    }
}
