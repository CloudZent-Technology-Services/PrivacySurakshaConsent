import XCTest
import WebKit
@testable import PrivacySurakshaConsent

/// The eleven conformance items every shell must pass
/// (parent design §8, EMBEDDED.md §8).
///
/// Items 1–9 drive the shell's own logic against the real committed catalogs
/// and the real WebView factory seam; items 10 and 11 drive the REAL committed
/// bundle in a REAL WKWebView on the simulator.
///
/// The bundle's own jsdom suite already proves the page behaves correctly when
/// driven correctly; it cannot prove the SHELL drives it correctly, which is
/// what this file is for.
///
/// Every number these produce is simulator-only and must never be quoted as a
/// device SLA (parent design §5.1, EMBEDDED.md gap 4).
final class ConformanceTests: XCTestCase {

    private var directory: URL!
    private var suiteName: String!
    private var keychainService: String!
    private let apiBase = URL(string: "https://api.example.com")!
    private let appKey = "app_0123456789abcdef0123456789abcdef"

    /// The config items 1–9 hand to `CompliantRuntime`.
    ///
    /// Deliberately abbreviated to the three keys those items actually
    /// interrogate: `consentValidityDays` and `purposes` are what
    /// `ConsentGate.decide` reads, and `categories` documents the shape. None
    /// of items 1–9 ever executes page JS — `CompliantRuntime` uses the
    /// default `.fileURL` loader, whose navigation never completes in a
    /// hostless XCTest process (see PageLoader), so `init` stays queued in
    /// `WebViewHost.pendingMessages` and no page ever parses this. Items 10
    /// and 11 DO boot the page and therefore use `fullConfig` instead; the
    /// difference is not an oversight.
    private let config = Data(#"""
    {"consentValidityDays":180,
     "purposes":[{"id":"analytics","key":"analytics","version":1,"name":"Analytics",
                  "description":"","lawfulBasis":"consent","retentionDays":90,
                  "essential":false,"categories":["analytics"]}],
     "categories":[{"key":"necessary","essential":true},
                   {"key":"analytics","essential":false}]}
    """#.utf8)

    /// A COMPLETE `PublicBannerConfig` — the only kind the real page will
    /// accept — for the two items that actually boot it.
    ///
    /// Modelled on `WebViewHostTests.fullConfig`, which in turn matches
    /// `configWith` in packages/banner/src/embedded.test.ts, the bundle's own
    /// fixture. This is not padding. A config missing a single required field
    /// makes the page throw INSIDE its `init` handler, after `ready` has
    /// already been posted, and the opaque origin that `.inlineHTML` forces
    /// reduces that throw to `"Script error. @0"` with no stack (PageLoader,
    /// consequence 2) — a whole Task 9 fix round went into diagnosing exactly
    /// that, caused by an omitted `languages`.
    ///
    /// `languages` is parameterised because `resolveLang`
    /// (packages/banner/src/lang.ts) only honours a seeded language that
    /// `config.languages` contains — otherwise it falls back to
    /// `defaultLang`. Item 10 driving `lang: "ur"` against a config that did
    /// not list `ur` would render English LTR and fail for a reason that has
    /// nothing to do with RTL support.
    private static func fullConfig(languages: [String]) -> Data {
        let list = languages.map { "\"\($0)\"" }.joined(separator: ",")
        return Data("""
        {"version":1,"logoUrl":null,"theme":{},\
        "bannerText":{"title":{},"description":{},"categories":{}},\
        "categories":["necessary","analytics"],"languages":[\(list)],"defaultLang":"en",\
        "googleConsentMode":true,"dsrEnabled":false,"grievanceEnabled":false,\
        "revokeEnabled":true,"otpRequired":false,"ageSelfDeclaration":false,\
        "grievanceResponseDays":30,"dsrResponseDays":30,"consentValidityDays":365,\
        "dpoOrContact":{},"noticeContent":{},"publishedAt":"2026-08-01T00:00:00.000Z"}
        """.utf8)
    }

    /// 240s, not 90s, for the two items that boot the page. The FIRST WebView
    /// in the test process pays a cold WebContent process launch — measured
    /// past 20s in this local sandbox during Task 9, while a warm one reaches
    /// `painted` in about 3s. On the actual macos-latest GitHub Actions
    /// runner, test10 — alphabetically the first test in the suite to boot a
    /// real page — genuinely exceeded 90s on 2026-09-01's first CI run (both
    /// the 90s render wait and the follow-on 10s JS-evaluation wait timed
    /// out, with the very next test's own boot completing in ~1.6s once the
    /// process was warm), so CI's cold-start cost is materially worse than
    /// this local sandbox's. A timeout only bounds how long a FAILURE takes
    /// to report, so the generous value costs a passing run nothing.
    private let bootTimeout: TimeInterval = 240

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suiteName = "com.compliant.conformance.\(UUID().uuidString)"
        keychainService = "com.compliant.conformance.\(UUID().uuidString)"
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults().removePersistentDomain(forName: suiteName)
        DeviceIdentifier(service: keychainService).reset()
        try super.tearDownWithError()
    }

    // MARK: - Harness

    @MainActor
    private func makeRuntime(
        outcomes: [StubHTTP.Outcome],
        factory: CountingFactory,
        seededPrefs: Data? = nil,
        seededLang: String? = nil,
        signalWriter: ConsentSignalWriter? = nil
    ) -> (CompliantRuntime, StubHTTP, PrefsStore) {
        let http = StubHTTP(outcomes)
        let store = PrefsStore(suiteName: suiteName)
        if seededPrefs != nil || seededLang != nil {
            store.write(prefs: seededPrefs, lang: seededLang)
        }
        var configuration = CompliantConfiguration(
            siteKey: "sk_test", apiBase: apiBase, appKey: appKey
        )
        configuration.signalWriter = signalWriter

        let runtime = CompliantRuntime(
            configuration: configuration,
            session: http,
            prefsStore: store,
            deviceIdentifier: DeviceIdentifier(service: keychainService),
            webViewFactory: factory,
            cacheDirectory: directory,
            now: { Date() }
        )
        return (runtime, http, store)
    }

    // MARK: - Item 1

    /// Fresh install shows the notice.
    @MainActor
    func test01_FreshInstallShowsTheNotice() async {
        let factory = CountingFactory()
        let (runtime, _, _) = makeRuntime(
            outcomes: [.success(status: 200, body: config)], factory: factory
        )
        await runtime.start()
        XCTAssertEqual(factory.creations, 1, "a fresh install must show the notice")
    }

    // MARK: - Item 2 — THE LATENCY ARGUMENT

    /// Second launch shows nothing AND creates no WebView.
    ///
    /// This is the single most load-bearing assertion in the suite, and item 1
    /// above is asserted alongside it deliberately: if this one ever starts
    /// passing vacuously — the factory bypassed, or the seeded decision never
    /// actually read — the whole latency claim becomes unverified while the
    /// suite still shows green. The positive case is what stops that.
    @MainActor
    func test02_SecondLaunchCreatesNoWebView() async {
        let factory = CountingFactory()
        let decision = Data("""
        {"v":1,"action":"accept_all","categories":{"necessary":true},
         "at":"\(ISO8601DateFormatter.compliant.string(from: Date()))"}
        """.utf8)
        let (runtime, _, _) = makeRuntime(
            outcomes: [.success(status: 200, body: config)],
            factory: factory, seededPrefs: decision
        )
        await runtime.start()
        XCTAssertEqual(factory.creations, 0, "no WebView may be created on a stored decision")
    }

    // MARK: - Items 3 and 4

    /// Accept-all writes local state, posts a record, and writes Consent Mode.
    @MainActor
    func test03_AcceptAllPersistsPostsAndSignals() async throws {
        let writer = SpySignalWriter()
        let (runtime, http, store) = makeRuntime(
            outcomes: [
                .success(status: 200, body: config),
                .success(status: 200, body: Data(#"{"recordId":"rec_1"}"#.utf8)),
            ],
            factory: CountingFactory(), signalWriter: writer
        )
        await runtime.start()

        let prefs = Data(#"{"v":1,"action":"accept_all","categories":{"analytics":true}}"#.utf8)
        runtime.handle(.persist(prefs: prefs, lang: nil))
        runtime.handle(.decision(prefs: prefs, signals: ["analytics_storage": .granted]))
        runtime.handle(.httpRequest(HTTPRequestSpec(
            id: "c1", method: "POST", path: "/api/v1/consent", body: prefs
        )))

        XCTAssertEqual(store.prefs, prefs, "local state written")
        XCTAssertEqual(writer.received.last?["analytics_storage"], .granted, "Consent Mode written")

        try await waitForRequest(in: http, path: "/api/v1/consent")
        let posted = try XCTUnwrap(http.requests.last)
        XCTAssertEqual(posted.httpMethod, "POST")
        XCTAssertEqual(
            posted.value(forHTTPHeaderField: "X-Compliant-App"), appKey,
            "row 384: an Origin-less consent POST must carry the app key"
        )
    }

    /// Reject-non-essential likewise.
    @MainActor
    func test04_RejectNonEssentialPersistsPostsAndSignals() async throws {
        let writer = SpySignalWriter()
        let (runtime, http, store) = makeRuntime(
            outcomes: [
                .success(status: 200, body: config),
                .success(status: 200, body: Data(#"{"recordId":"rec_2"}"#.utf8)),
            ],
            factory: CountingFactory(), signalWriter: writer
        )
        await runtime.start()

        let prefs = Data(#"{"v":1,"action":"reject_non_essential","categories":{"analytics":false}}"#.utf8)
        runtime.handle(.persist(prefs: prefs, lang: nil))
        runtime.handle(.decision(prefs: prefs, signals: ["analytics_storage": .denied]))
        runtime.handle(.httpRequest(HTTPRequestSpec(
            id: "c2", method: "POST", path: "/api/v1/consent", body: prefs
        )))

        XCTAssertEqual(store.prefs, prefs)
        XCTAssertEqual(writer.received.last?["analytics_storage"], .denied)
        try await waitForRequest(in: http, path: "/api/v1/consent")
    }

    // MARK: - Item 5

    /// A per-purpose save round-trips through the bridge: persisted by the
    /// page, then readable as the `prefs` a later init would carry.
    @MainActor
    func test05_PerPurposeSaveRoundTripsThroughTheBridge() async {
        let saved = Data(#"""
        {"v":1,"action":"save_preferences","categories":{"necessary":true,"analytics":false},
         "at":"2026-08-01T00:00:00.000Z"}
        """#.utf8)

        let (first, _, store) = makeRuntime(
            outcomes: [.success(status: 200, body: config)], factory: CountingFactory()
        )
        await first.start()
        first.handle(.persist(prefs: saved, lang: "hi"))
        XCTAssertEqual(store.prefs, saved)

        // A new store over the same suite is the next launch: the decision
        // must have outlived the WebView that produced it.
        let reopened = PrefsStore(suiteName: suiteName)
        XCTAssertEqual(reopened.prefs, saved, "the decision survives the WebView's death")
        XCTAssertEqual(reopened.lang, "hi", "so does the language")
    }

    // MARK: - Item 6

    /// Withdrawal is reachable and posts to /consent/revoke.
    @MainActor
    func test06_WithdrawalPostsToRevoke() async throws {
        let (runtime, http, _) = makeRuntime(
            outcomes: [
                .success(status: 200, body: config),
                .success(status: 200, body: Data("{}".utf8)),
            ],
            factory: CountingFactory()
        )
        await runtime.start()

        runtime.handle(.httpRequest(HTTPRequestSpec(
            id: "w1", method: "POST", path: "/api/v1/consent/revoke",
            body: Data(#"{"siteKey":"sk_test"}"#.utf8)
        )))

        try await waitForRequest(in: http, path: "/api/v1/consent/revoke")
        XCTAssertEqual(
            http.requests.last?.value(forHTTPHeaderField: "X-Compliant-App"), appKey,
            "revoke enforces row 384 too"
        )
    }

    // MARK: - Items 7 and 8

    /// Airplane mode with a cached config still shows the notice.
    @MainActor
    func test07_OfflineWithACacheStillShowsTheNotice() async {
        let warm = makeRuntime(
            outcomes: [.success(status: 200, body: config)], factory: CountingFactory()
        ).0
        await warm.start()

        let factory = CountingFactory()
        let (offline, _, _) = makeRuntime(
            outcomes: [.failure(StubHTTP.StubError.offline)], factory: factory
        )
        await offline.start()
        XCTAssertEqual(factory.creations, 1)
    }

    /// Airplane mode with NO cached config shows nothing.
    @MainActor
    func test08_OfflineWithNoCacheShowsNothing() async {
        let factory = CountingFactory()
        var reported: Error?
        let (runtime, http, store) = makeRuntime(
            outcomes: [.failure(StubHTTP.StubError.offline)], factory: factory
        )
        runtime.onError = { reported = $0 }
        await runtime.start()

        XCTAssertEqual(factory.creations, 0, "never invent a notice")
        XCTAssertNil(store.prefs, "and record no consent")
        XCTAssertNotNil(reported)
        XCTAssertEqual(http.requests.count, 1, "one attempt, then stop")
    }

    // MARK: - Item 9

    /// A non-English locale renders from bundled assets with no network.
    @MainActor
    func test09_ANonEnglishLocaleComesFromBundledAssets() async {
        let (runtime, http, _) = makeRuntime(
            outcomes: [.success(status: 200, body: config)], factory: CountingFactory()
        )
        await runtime.start()
        let requestsAfterConfig = http.requests.count

        runtime.handle(.catalogRequest(lang: "hi"))

        XCTAssertNotNil(CatalogReader().catalog(for: "hi"), "hi is bundled")
        XCTAssertEqual(
            http.requests.count, requestsAfterConfig,
            "a catalog must come off disk, never over the network"
        )
    }

    // MARK: - Item 10

    /// Right-to-left renders correctly in Urdu.
    ///
    /// Loads the real bundle in a real WKWebView and asks the DOM, rather than
    /// asserting on the catalog file — the question is whether the rendered
    /// NOTICE is RTL, not whether the translation exists.
    ///
    /// `EmbeddedBundle.resolve()` rather than `Bundle.module`, and
    /// `.inlineHTML` rather than the default `.fileURL`, for the two reasons
    /// spelled out in EmbeddedBundle and PageLoader: inside this test target
    /// `Bundle.module` is the TEST bundle (renewal-cases.json only), and
    /// `loadFileURL` in a hostless XCTest process neither completes nor fails.
    @MainActor
    func test10_UrduRendersRightToLeft() throws {
        let rendered = expectation(description: "banner rendered in ur")
        var renderedFulfilled = false
        var errors: [String] = []
        var host: WebViewHost?

        host = WebViewHost(
            factory: CountingFactory(),
            bundle: try EmbeddedBundle.resolve(),
            loader: .inlineHTML(try EmbeddedBundle.inlinedPage())
        ) { event in
            switch event {
            case .catalogRequest(let lang):
                host?.send(.catalog(lang: lang, catalog: CatalogReader().catalog(for: lang)))
            case .viewChanged(let view) where view != .hidden:
                // Guarded: the page posts a viewChanged on every view
                // transition, and a second fulfill on one expectation is
                // itself a test failure.
                if !renderedFulfilled {
                    renderedFulfilled = true
                    rendered.fulfill()
                }
            case .error(let message):
                // Collected, not ignored: a page error here is the difference
                // between a named cause and a bare timeout.
                errors.append(message)
            default:
                break
            }
        }

        host?.prewarm()
        host?.send(.init_(
            siteKey: "sk_test", apiBase: apiBase.absoluteString,
            visitorId: UUID().uuidString.lowercased(),
            // "ur" must be in config.languages or resolveLang falls back to
            // defaultLang and this renders LTR English — see fullConfig.
            config: Self.fullConfig(languages: ["en", "ur"]),
            prefs: nil, lang: "ur"
        ))

        wait(for: [rendered], timeout: bootTimeout)
        XCTAssertTrue(errors.isEmpty, "the page must boot with no error: \(errors)")

        let evaluated = expectation(description: "dir read")
        var direction: String?
        // render.ts sets `dir` on the shadow HOST (`root.host`), not on a node
        // inside the shadow root, so the host element is checked first. The
        // in-root and document-level lookups are kept as fallbacks against a
        // future move of that attribute.
        host?.evaluateForTesting("""
        (function () {
          var all = document.querySelectorAll('*');
          for (var i = 0; i < all.length; i++) {
            if (!all[i].shadowRoot) continue;
            var onHost = all[i].getAttribute('dir');
            if (onHost) return onHost;
            var inside = all[i].shadowRoot.querySelector('[dir]');
            if (inside) return inside.getAttribute('dir');
          }
          var direct = document.querySelector('[dir]');
          return direct ? direct.getAttribute('dir')
                        : (document.documentElement.getAttribute('dir') || '');
        })()
        """) { result in
            direction = result as? String
            evaluated.fulfill()
        }
        // Same CI-cold-start margin as bootTimeout above: evaluateJavaScript
        // runs on the same WebContent process the render wait above was
        // waiting on, so if that process is still catching up this call
        // inherits the same slowness, not an independent 10s budget.
        wait(for: [evaluated], timeout: bootTimeout)

        XCTAssertEqual(direction, "rtl", "Urdu must render right-to-left")
    }

    // MARK: - Item 11

    /// timeToReady and timeToPaint are reported.
    ///
    /// The NUMBERS belong to the physical-device ledger row; what is asserted
    /// here is that the shell receives and can report them at all.
    @MainActor
    func test11_ReadyAndPaintTimingsAreReported() throws {
        let ready = expectation(description: "ready")
        let painted = expectation(description: "painted")
        var readyMs: Double?
        var paintMs: Double?
        var errors: [String] = []
        var host: WebViewHost?

        host = WebViewHost(
            factory: CountingFactory(),
            bundle: try EmbeddedBundle.resolve(),
            loader: .inlineHTML(try EmbeddedBundle.inlinedPage())
        ) { event in
            switch event {
            case .ready(let ms):
                readyMs = ms
                ready.fulfill()
            case .painted(let ms):
                paintMs = ms
                painted.fulfill()
            case .catalogRequest(let lang):
                host?.send(.catalog(lang: lang, catalog: CatalogReader().catalog(for: lang)))
            case .error(let message):
                errors.append(message)
            default:
                break
            }
        }

        host?.prewarm()
        host?.send(.init_(
            siteKey: "sk_test", apiBase: apiBase.absoluteString,
            visitorId: UUID().uuidString.lowercased(),
            config: Self.fullConfig(languages: ["en"]),
            prefs: nil, lang: nil
        ))

        wait(for: [ready, painted], timeout: bootTimeout, enforceOrder: true)
        XCTAssertTrue(errors.isEmpty, "the page must boot with no error: \(errors)")

        let readyValue = try XCTUnwrap(readyMs)
        let paintValue = try XCTUnwrap(paintMs)
        XCTAssertGreaterThanOrEqual(readyValue, 0)
        XCTAssertGreaterThanOrEqual(paintValue, 0)
        XCTAssertTrue(readyValue.isFinite && paintValue.isFinite)

        // Recorded, not asserted against a threshold: a simulator runs on the
        // Mac's CPU and is optimistic by construction. The physical-device
        // measurement is its own ledger row.
        print("[conformance] simulator timeToReady=\(readyValue)ms timeToPaint=\(paintValue)ms")
    }

    // MARK: - Helpers

    private final class SpySignalWriter: ConsentSignalWriter {
        private(set) var received: [[String: ConsentSignalState]] = []
        func write(_ signals: [String: ConsentSignalState]) throws {
            received.append(signals)
        }
    }

    /// httpRequest handling runs in a detached Task, so the assertion has to
    /// wait for it rather than reading immediately.
    private func waitForRequest(
        in http: StubHTTP, path: String, timeout: TimeInterval = 5
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if http.requests.contains(where: { $0.url?.path == path }) { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        XCTFail("no request to \(path) within \(timeout)s")
    }
}

extension ISO8601DateFormatter {
    /// SavedPrefs.at is always `new Date().toISOString()` — internet date time
    /// with three fractional digits.
    static let compliant: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
