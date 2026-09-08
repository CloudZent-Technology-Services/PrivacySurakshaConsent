import XCTest
@testable import PrivacySurakshaConsent

/// The wiring: config load -> gate -> prewarm-or-stop -> init -> events.
/// Conformance items 1, 2, 7 and 8 appear here in pure form; ConformanceTests
/// re-asserts them end to end against the real bundle.
final class CompliantConsentTests: XCTestCase {

    private var directory: URL!
    private var suiteName: String!
    private let apiBase = URL(string: "https://api.example.com")!
    private let config = Data(#"{"consentValidityDays":180,"purposes":[],"categories":[]}"#.utf8)

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        suiteName = "com.compliant.tests.\(UUID().uuidString)"
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults().removePersistentDomain(forName: suiteName)
        try super.tearDownWithError()
    }

    @MainActor
    private func makeRuntime(
        http: StubHTTP,
        factory: CountingFactory,
        seededPrefs: Data? = nil,
        signalWriter: ConsentSignalWriter? = nil
    ) -> CompliantRuntime {
        let store = PrefsStore(suiteName: suiteName)
        if let seededPrefs { store.write(prefs: seededPrefs, lang: nil) }
        var configuration = CompliantConfiguration(siteKey: "sk_test", apiBase: apiBase)
        configuration.signalWriter = signalWriter
        return CompliantRuntime(
            configuration: configuration,
            session: http,
            prefsStore: store,
            deviceIdentifier: DeviceIdentifier(service: "com.compliant.tests.\(UUID().uuidString)"),
            webViewFactory: factory,
            cacheDirectory: directory,
            now: { Date(timeIntervalSince1970: 1_785_000_000) }
        )
    }

    /// Conformance item 1 — a fresh install shows the notice, so a WebView
    /// must be created.
    @MainActor
    func testFreshInstallCreatesAWebView() async {
        let factory = CountingFactory()
        let runtime = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]), factory: factory
        )
        await runtime.start()
        XCTAssertEqual(factory.creations, 1)
    }

    /// Conformance item 2 — THE LATENCY ARGUMENT. A launch with a valid stored
    /// decision must create NO WebView. If this ever passes vacuously the
    /// whole architecture is unverified while the suite still shows green,
    /// which is why the item-1 test above asserts the positive case too.
    @MainActor
    func testSecondLaunchWithAValidDecisionCreatesNoWebView() async {
        let factory = CountingFactory()
        // now() is pinned inside the 180-day window of this decision, so it is
        // neither expired nor drifted.
        let fresh = Data(#"{"v":1,"action":"accept_all","at":"2026-08-01T00:00:00.000Z"}"#.utf8)
        let runtime = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]),
            factory: factory, seededPrefs: fresh
        )
        await runtime.start()
        XCTAssertEqual(factory.creations, 0, "a stored valid decision must create no WebView")
    }

    /// An EXPIRED decision must re-prompt, which means a WebView.
    @MainActor
    func testAnExpiredDecisionCreatesAWebView() async {
        let factory = CountingFactory()
        let stale = Data(#"{"v":1,"action":"accept_all","at":"2020-01-01T00:00:00.000Z"}"#.utf8)
        let runtime = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]),
            factory: factory, seededPrefs: stale
        )
        await runtime.start()
        XCTAssertEqual(factory.creations, 1, "an expired decision must re-prompt")
    }

    /// A DRIFTED decision must re-prompt too (ledger 341). This is the case a
    /// shell that only checked "does a decision exist?" would silently miss.
    @MainActor
    func testAMateriallyChangedPurposeCreatesAWebView() async {
        let factory = CountingFactory()
        let drifting = Data(#"""
        {"consentValidityDays":180,
         "purposes":[{"id":"a","materialSince":"2026-08-15T00:00:00.000Z"}]}
        """#.utf8)
        let decided = Data(#"{"v":1,"action":"accept_all","at":"2026-08-01T00:00:00.000Z"}"#.utf8)
        let store = PrefsStore(suiteName: suiteName)
        store.write(prefs: decided, lang: nil)
        let runtime = CompliantRuntime(
            configuration: CompliantConfiguration(siteKey: "sk_test", apiBase: apiBase),
            session: StubHTTP([.success(status: 200, body: drifting)]),
            prefsStore: store,
            deviceIdentifier: DeviceIdentifier(service: "com.compliant.tests.\(UUID().uuidString)"),
            webViewFactory: factory,
            cacheDirectory: directory,
            now: { Date(timeIntervalSince1970: 1_785_000_000) }
        )
        await runtime.start()
        XCTAssertEqual(factory.creations, 1, "a material change must re-prompt")
    }

    /// Conformance item 8 — no cache, no network: show nothing, record
    /// nothing, and tell the customer.
    @MainActor
    func testNoConfigAndNoCacheShowsNothingAndReportsAnError() async {
        let factory = CountingFactory()
        var reported: Error?
        let runtime = makeRuntime(http: StubHTTP(alwaysOffline: true), factory: factory)
        runtime.onError = { reported = $0 }

        await runtime.start()
        XCTAssertEqual(factory.creations, 0, "never invent a notice")
        XCTAssertNotNil(reported)
    }

    /// Conformance item 7 — offline WITH a cache still shows the notice.
    @MainActor
    func testOfflineWithACachedConfigStillShowsTheNotice() async {
        let warm = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]), factory: CountingFactory()
        )
        await warm.start()

        let factory = CountingFactory()
        let offline = makeRuntime(http: StubHTTP(alwaysOffline: true), factory: factory)
        await offline.start()
        XCTAssertEqual(factory.creations, 1, "a cached config is enough to show the notice")
    }

    /// The visitor id sent on init must be the UUID the page will accept —
    /// isHostMessage rejects anything else and the notice never renders.
    @MainActor
    func testTheInitVisitorIdIsAUUID() async throws {
        let runtime = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]), factory: CountingFactory()
        )
        await runtime.start()
        let sent = try XCTUnwrap(runtime.lastInitVisitorId)
        XCTAssertNotNil(UUID(uuidString: sent))
    }

    /// A `persist` event must reach durable storage. The page's own copy dies
    /// with the WebView, so this is the only copy.
    @MainActor
    func testPersistWritesThroughToTheStore() async {
        let store = PrefsStore(suiteName: suiteName)
        let runtime = CompliantRuntime(
            configuration: CompliantConfiguration(siteKey: "sk", apiBase: apiBase),
            session: StubHTTP([.success(status: 200, body: config)]),
            prefsStore: store,
            deviceIdentifier: DeviceIdentifier(service: "com.compliant.tests.\(UUID().uuidString)"),
            webViewFactory: CountingFactory(),
            cacheDirectory: directory,
            now: { Date() }
        )
        let prefs = Data(#"{"v":1,"action":"accept_all"}"#.utf8)
        runtime.handle(.persist(prefs: prefs, lang: "hi"))
        XCTAssertEqual(store.prefs, prefs)
        XCTAssertEqual(store.lang, "hi")
    }

    /// A decision reaches the signal writer, and a throwing writer never costs
    /// the consent record (parent design 7).
    @MainActor
    func testDecisionReachesTheSignalWriterAndAThrowIsSwallowed() async {
        final class ThrowingWriter: ConsentSignalWriter {
            private(set) var called = false
            func write(_ signals: [String: ConsentSignalState]) throws {
                called = true
                throw NSError(domain: "test", code: 1)
            }
        }
        let writer = ThrowingWriter()
        var reported: Error?
        let runtime = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]),
            factory: CountingFactory(), signalWriter: writer
        )
        runtime.onError = { reported = $0 }

        // Must not crash and must not propagate.
        runtime.handle(.decision(prefs: Data("{}".utf8), signals: ["analytics_storage": .granted]))
        XCTAssertTrue(writer.called)
        XCTAssertNotNil(reported, "the throw is reported, not silently dropped")
    }

    // MARK: - Fix round 1, finding 1: show(_:) must not be a silent no-op

    /// THE BUG. On every launch after the first, JOB 1 stops start() before a
    /// WebView exists — correctly, that is the latency argument. But the app's
    /// "Privacy settings" button then called show(_:) into a host with no
    /// WebView, and WebViewHost.send drops silently in that state. So the
    /// button did nothing, with no error, forever.
    ///
    /// Asserted at the moment of the call, not just at the end: creations must
    /// be 0 after start() and 1 after show(), which is the difference between
    /// "lazily prewarmed by show()" and "the gate never fired".
    @MainActor
    func testShowLazilyCreatesTheWebViewWhenJobOneSaidNoDecisionWasNeeded() async {
        let factory = CountingFactory()
        let fresh = Data(#"{"v":1,"action":"accept_all","at":"2026-08-01T00:00:00.000Z"}"#.utf8)
        let runtime = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]),
            factory: factory, seededPrefs: fresh
        )

        await runtime.start()
        XCTAssertEqual(factory.creations, 0, "job 1's fast path must still create nothing")
        XCTAssertFalse(runtime.host.didCreateWebView)

        runtime.show(.prefs)
        XCTAssertEqual(factory.creations, 1, "show() must lazily prewarm")
        XCTAssertTrue(runtime.host.didCreateWebView)
    }

    /// The page cannot act on `view` until `init` has told it who it is and
    /// what the config is, so the lazy path must send both, in that order.
    /// In a hostless test bundle the document never finishes loading, so
    /// everything sent sits in the host's queue — which is exactly the order
    /// it will be delivered in.
    @MainActor
    func testTheLazyShowPathSendsInitBeforeView() async throws {
        let fresh = Data(#"{"v":1,"action":"accept_all","at":"2026-08-01T00:00:00.000Z"}"#.utf8)
        let runtime = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]),
            factory: CountingFactory(), seededPrefs: fresh
        )
        await runtime.start()
        XCTAssertTrue(runtime.host.pendingMessages.isEmpty, "nothing is sent before show()")

        runtime.show(.prefs)

        let queued = runtime.host.pendingMessages
        XCTAssertEqual(queued.count, 2)
        XCTAssertTrue(queued[0].contains(#""type":"init""#), "got \(queued[0])")
        XCTAssertTrue(queued[1].contains(#""type":"view""#), "got \(queued[1])")
        XCTAssertTrue(queued[1].contains(#""view":"prefs""#), "got \(queued[1])")
        // The init it sends must carry the config start() retained, otherwise
        // the page throws inside its own init handler and stalls silently.
        XCTAssertTrue(queued[0].contains("consentValidityDays"), "got \(queued[0])")
        XCTAssertNotNil(UUID(uuidString: try XCTUnwrap(runtime.lastInitVisitorId)))
    }

    /// A second show() must not create a second WebView — one per session
    /// (WebViewHost rule 2: never release it, never duplicate it).
    @MainActor
    func testASecondShowReusesTheSameWebView() async {
        let factory = CountingFactory()
        let fresh = Data(#"{"v":1,"action":"accept_all","at":"2026-08-01T00:00:00.000Z"}"#.utf8)
        let runtime = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]),
            factory: factory, seededPrefs: fresh
        )
        await runtime.start()
        runtime.show(.prefs)
        runtime.show(.dsr)
        XCTAssertEqual(factory.creations, 1, "one WebView per session, always")
        XCTAssertEqual(runtime.host.pendingMessages.count, 3, "init, view, view — init sent once")
    }

    /// show() on the auto-launch path must NOT re-send init: start() already
    /// prewarmed, so this is a plain view switch.
    @MainActor
    func testShowAfterAnAutoLaunchDoesNotResendInit() async {
        let factory = CountingFactory()
        let runtime = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]), factory: factory
        )
        await runtime.start()
        XCTAssertEqual(factory.creations, 1)

        runtime.show(.prefs)
        XCTAssertEqual(factory.creations, 1)
        let queued = runtime.host.pendingMessages
        XCTAssertEqual(queued.filter { $0.contains(#""type":"init""#) }.count, 1)
    }

    /// Finding 1, point 3 — show() with no config ever resolved. Nothing can be
    /// rendered honestly (rule 5 forbids inventing a notice), so the chosen
    /// behaviour is: report through onError, create no WebView, show nothing.
    /// Never crash, never a broken sheet.
    @MainActor
    func testShowWithNoConfigEverResolvedReportsAnErrorAndShowsNothing() async {
        let factory = CountingFactory()
        var reported: [Error] = []
        let runtime = makeRuntime(http: StubHTTP(alwaysOffline: true), factory: factory)
        runtime.onError = { reported.append($0) }

        await runtime.start()
        XCTAssertEqual(reported.count, 1, "rule 5 reported once by start()")

        runtime.show(.prefs)
        XCTAssertEqual(factory.creations, 0, "no config means no WebView, ever")
        XCTAssertTrue(runtime.host.pendingMessages.isEmpty)
        XCTAssertEqual(reported.count, 2, "show() reports its own refusal too")
        XCTAssertTrue(
            reported[1].localizedDescription.contains("no consent config is available"),
            "got \(reported[1].localizedDescription)"
        )
    }

    /// show() before start() has even been called at all. Same contract.
    @MainActor
    func testShowBeforeStartIsASafeReportedNoOp() {
        let factory = CountingFactory()
        var reported: Error?
        let runtime = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]), factory: factory
        )
        runtime.onError = { reported = $0 }

        runtime.show(.banner)
        XCTAssertEqual(factory.creations, 0)
        XCTAssertNotNil(reported)
    }

    // MARK: - Fix round 1, finding 2: design rule 3, read disk first

    /// THE IMPORTANT ONE. Rule 3 is "on later launches, read disk first, then
    /// refresh in the background". Before this round start() awaited the
    /// network unconditionally, so a warm cache bought nothing and a slow
    /// network delayed the notice by the full request time.
    ///
    /// `.never` is a request that never answers. If start() awaited it, this
    /// test CANNOT return — so the fact that it completes at all, with the
    /// gate already decided and the WebView already prewarmed, is the proof
    /// that the disk copy answered the gate. That is a genuinely different
    /// code path, not the old one passing again.
    @MainActor
    func testAWarmDiskCacheAnswersTheGateWithoutWaitingOnTheNetwork() async {
        // Warm the on-disk cache the way ConfigCacheTests does: a real
        // ConfigCache against the same directory the runtime will read.
        let warm = ConfigCache(
            siteKey: "sk_test", apiBase: apiBase,
            session: StubHTTP([.success(status: 200, body: config)]), directory: directory
        )
        _ = await warm.load()
        XCTAssertEqual(warm.cached(), config, "precondition: the disk cache is warm")

        let hanging = StubHTTP([.never])
        let factory = CountingFactory()
        let runtime = makeRuntime(http: hanging, factory: factory)

        let started = Date()
        await runtime.start()
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertEqual(factory.creations, 1, "the disk copy must answer the gate on its own")
        XCTAssertLessThan(elapsed, 2, "start() must not wait on the network when disk answered")
    }

    /// The other half of rule 3: the refresh still happens, just unawaited, so
    /// the NEXT launch gets fresh config. A disk-first read that skipped the
    /// refresh would freeze the config forever.
    @MainActor
    func testAWarmDiskCacheStillRefreshesInTheBackground() async throws {
        let fresher = Data(#"{"consentValidityDays":90,"purposes":[],"categories":[]}"#.utf8)
        let warm = ConfigCache(
            siteKey: "sk_test", apiBase: apiBase,
            session: StubHTTP([.success(status: 200, body: config)]), directory: directory
        )
        _ = await warm.load()

        let network = StubHTTP([.success(status: 200, body: fresher)])
        let runtime = makeRuntime(http: network, factory: CountingFactory())
        await runtime.start()

        // The refresh is detached, so poll rather than assume it already ran.
        let deadline = Date().addingTimeInterval(5)
        while warm.cached() != fresher, Date() < deadline {
            try await Task.sleep(nanoseconds: 20 * NSEC_PER_MSEC)
        }
        XCTAssertEqual(warm.cached(), fresher, "the background refresh must update the disk copy")
    }

    /// A background refresh that FAILS while a valid disk cache already
    /// answered the gate is rule 4 working as designed, not a customer-visible
    /// error. Reporting it would train customers to ignore onError.
    @MainActor
    func testAFailedBackgroundRefreshIsNotReportedWhenTheCacheAnswered() async throws {
        let warm = ConfigCache(
            siteKey: "sk_test", apiBase: apiBase,
            session: StubHTTP([.success(status: 200, body: config)]), directory: directory
        )
        _ = await warm.load()

        var reported: [Error] = []
        let factory = CountingFactory()
        let runtime = makeRuntime(http: StubHTTP(alwaysOffline: true), factory: factory)
        runtime.onError = { reported.append($0) }

        await runtime.start()
        // Give the detached refresh time to fail.
        try await Task.sleep(nanoseconds: 200 * NSEC_PER_MSEC)

        XCTAssertEqual(factory.creations, 1, "the cache is enough to show the notice")
        // Narrowed to config errors on purpose: a Keychain failure is a
        // legitimate separate report on this path, and in an unsigned test
        // process the Keychain always fails with -34018 (the same cause as the
        // known DeviceIdentifierTests failures). Asserting "no errors at all"
        // would make this test about the sandbox rather than about rule 4.
        XCTAssertTrue(
            reported.compactMap { $0 as? ConfigCacheError }.isEmpty,
            "a cache hit is not a config error the customer needs to see: got \(reported)"
        )
    }

    // MARK: - Fix round 1, finding 3: previously untested event paths

    /// A page-reported error must reach the customer's onError with the page's
    /// own message intact — a generic "something failed" is undebuggable.
    @MainActor
    func testAPageErrorEventIsReportedThroughOnError() throws {
        var reported: Error?
        let runtime = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]), factory: CountingFactory()
        )
        runtime.onError = { reported = $0 }

        runtime.handle(.error(message: "renderer blew up"))

        let error = try XCTUnwrap(reported)
        XCTAssertEqual(error.localizedDescription, "renderer blew up")
        XCTAssertEqual((error as NSError).domain, "com.compliant.consent")
    }

    /// A catalogRequest must be answered with a `catalog` message for the SAME
    /// language, carrying the real bundled strings. An unanswered request
    /// leaves the page with no copy to render.
    @MainActor
    func testACatalogRequestIsAnsweredWithTheCatalogForThatLanguage() async throws {
        let runtime = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]), factory: CountingFactory()
        )
        await runtime.start()
        let beforeCount = runtime.host.pendingMessages.count

        runtime.handle(.catalogRequest(lang: "hi"))

        let queued = runtime.host.pendingMessages
        XCTAssertEqual(queued.count, beforeCount + 1, "exactly one reply")
        let reply = try XCTUnwrap(queued.last)
        XCTAssertTrue(reply.contains(#""type":"catalog""#), "got \(reply)")
        XCTAssertTrue(reply.contains(#""lang":"hi""#), "got \(reply)")
        XCTAssertFalse(
            reply.contains(#""catalog":null"#),
            "hi.json is bundled, so a null catalog means the reader did not find it"
        )
    }

    /// An unknown language must still get a reply rather than silence — the
    /// page is waiting on one. A null catalog is the honest answer.
    @MainActor
    func testACatalogRequestForAnUnknownLanguageStillGetsAReply() async throws {
        let runtime = makeRuntime(
            http: StubHTTP([.success(status: 200, body: config)]), factory: CountingFactory()
        )
        await runtime.start()

        runtime.handle(.catalogRequest(lang: "zz"))

        let reply = try XCTUnwrap(runtime.host.pendingMessages.last)
        XCTAssertTrue(reply.contains(#""type":"catalog""#), "got \(reply)")
        XCTAssertTrue(reply.contains(#""lang":"zz""#), "got \(reply)")
    }
}
