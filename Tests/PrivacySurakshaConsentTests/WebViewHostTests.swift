import XCTest
import WebKit
@testable import PrivacySurakshaConsent

/// JOB 2 — prewarm and host the WebView.
///
/// Every host here is handed `EmbeddedBundle.resolve()` rather than
/// `Bundle.module`. That is not a stylistic choice: inside this test target
/// `Bundle.module` is the TEST target's bundle, which holds only
/// renewal-cases.json, so `prewarm()` would find no index.html, report
/// "embedded bundle missing" and never navigate. See EmbeddedBundle for the
/// full explanation. The one deliberate exception is the missing-bundle test
/// at the bottom, which wants a bundle with no page in it.
final class WebViewHostTests: XCTestCase {

    /// Prewarming means NAVIGATING, not allocating. Bare allocation measured
    /// 4.3 ms; navigation to the first line of page JS measured 330.5 ms
    /// (parent design 5, phase A). A host that only allocates has done
    /// nothing useful.
    @MainActor
    func testPrewarmCreatesAndNavigatesExactlyOneWebView() throws {
        let factory = CountingFactory()
        let host = WebViewHost(factory: factory, bundle: try EmbeddedBundle.resolve(), onEvent: { _ in })

        XCTAssertEqual(factory.creations, 0, "no WebView before prewarm")
        host.prewarm()
        XCTAssertEqual(factory.creations, 1)
        XCTAssertTrue(host.didCreateWebView)
    }

    @MainActor
    func testPrewarmIsIdempotent() throws {
        let factory = CountingFactory()
        let host = WebViewHost(factory: factory, bundle: try EmbeddedBundle.resolve(), onEvent: { _ in })
        host.prewarm()
        host.prewarm()
        host.prewarm()
        XCTAssertEqual(factory.creations, 1, "one WebView per session, always")
    }

    /// The notice starts hidden. The page tells the shell when to show it, via
    /// the first viewChanged that is not 'hidden'.
    @MainActor
    func testStartsHidden() throws {
        let host = WebViewHost(factory: CountingFactory(), bundle: try EmbeddedBundle.resolve(), onEvent: { _ in })
        host.prewarm()
        XCTAssertFalse(host.isVisible)
    }

    @MainActor
    func testVisibilityTogglesWithoutDestroyingTheWebView() throws {
        let factory = CountingFactory()
        let host = WebViewHost(factory: factory, bundle: try EmbeddedBundle.resolve(), onEvent: { _ in })
        host.prewarm()

        host.setVisible(true)
        XCTAssertTrue(host.isVisible)

        host.setVisible(false)
        XCTAssertFalse(host.isVisible)

        // The load-bearing assertion: hiding must not release the WebView.
        // Releasing costs the full ~330 ms again, AND loses the second
        // persist+decision pair that a successful consent POST fires after
        // viewChanged:'hidden' — the pair carrying recordId and atServer
        // (EMBEDDED.md section 4).
        XCTAssertEqual(factory.creations, 1, "hiding must never release the WebView")
        XCTAssertTrue(host.didCreateWebView)
    }

    /// The minimum COMPLETE `PublicBannerConfig` the page will accept.
    ///
    /// Matches `configWith` in packages/banner/src/embedded.test.ts, the
    /// bundle's own test fixture — not a claim of completeness against every
    /// non-optional field of `BannerConfigCommon` (packages/shared/src/index.ts):
    /// `position` is required there too but is absent from both this and
    /// `configWith`, and the page tolerates its absence. What matters is that
    /// this is a config the real bundle is proven to accept. This is not
    /// padding: a config
    /// missing a single required field makes the page throw INSIDE its `init`
    /// handler, after `ready` has already been posted, and the opaque origin
    /// that `.inlineHTML` forces reduces that throw to `"Script error. @0"`
    /// with no stack (see PageLoader, consequence 2). The original Task 9
    /// config omitted `languages`; `resolveLang` threw on it and every event
    /// after `ready` silently vanished — which was then misread as a Web
    /// Storage limitation of the opaque origin. It was not.
    private static let fullConfig = """
    {"version":1,"logoUrl":null,"theme":{},\
    "bannerText":{"title":{},"description":{},"categories":{}},\
    "categories":["necessary","analytics"],"languages":["en"],"defaultLang":"en",\
    "googleConsentMode":true,"dsrEnabled":false,"grievanceEnabled":false,\
    "revokeEnabled":true,"otpRequired":false,"ageSelfDeclaration":false,\
    "grievanceResponseDays":30,"dsrResponseDays":30,"consentValidityDays":365,\
    "dpoOrContact":{},"noticeContent":{},"publishedAt":"2026-08-01T00:00:00.000Z"}
    """

    /// The real bundle boots, reports `ready`, and then renders.
    ///
    /// This is the first thing in the project that proves EMBEDDED.md section
    /// 5's Swift transport row — a WKScriptMessageHandler named "compliant" —
    /// rather than assuming it. It exercises the whole round trip: the shell
    /// queues `init`, delivers it once the document exists, the page runs,
    /// posts through the handler, and the bridge decodes it into a `PageEvent`.
    ///
    /// It asserts the FULL guaranteed opening sequence (EMBEDDED.md section
    /// 4): `ready`, then a `viewChanged` that is not 'hidden', then `painted`
    /// — a fresh install with no stored decision must show the banner and
    /// actually finish rendering it. Waiting only for `ready` would pass on a
    /// page that booted and then died, which is exactly what a malformed
    /// config does; see `fullConfig`. `painted` is included because it is the
    /// docblocks' own headline claim (WebViewHost's PageLoader doc,
    /// EmbeddedBundle's doc) about what `.inlineHTML` can now prove — a claim
    /// that must be tested, not just measured once and written down.
    @MainActor
    func testTheRealBundleBootsAndRendersTheBanner() throws {
        let readyReceived = expectation(description: "ready")
        let viewChangedReceived = expectation(description: "viewChanged")
        let paintedReceived = expectation(description: "painted")

        var gotReady = false
        var viewChangedBeforeReady = false
        var firstView: CompliantView?
        var errors: [String] = []

        let host = WebViewHost(
            factory: CountingFactory(),
            bundle: try EmbeddedBundle.resolve(),
            loader: .inlineHTML(try EmbeddedBundle.inlinedPage())
        ) { event in
            switch event {
            case .ready:
                gotReady = true
                readyReceived.fulfill()
            case .viewChanged(let view):
                // 'ready' always precedes the first viewChanged — a
                // guaranteed, load-bearing ordering (EMBEDDED.md section 4).
                if !gotReady { viewChangedBeforeReady = true }
                if firstView == nil {
                    firstView = view
                    viewChangedReceived.fulfill()
                }
            case .painted:
                paintedReceived.fulfill()
            case .error(let message):
                // Collected rather than ignored: a page error here is the
                // failure mode this test exists to catch, and reporting it is
                // the difference between a named cause and a bare timeout.
                errors.append(message)
            default:
                break
            }
        }

        host.prewarm()
        host.send(.init_(
            siteKey: "sk_test",
            apiBase: "https://api.example.com",
            visitorId: UUID().uuidString.lowercased(),
            config: Data(Self.fullConfig.utf8),
            prefs: nil,
            lang: nil
        ))

        // Ordered, so a viewChanged or painted that arrives before its
        // predecessor fails here too. 90s because the FIRST WebView in the
        // test process pays a cold WebContent process launch — measured past
        // 20s in this sandbox; a warm one reaches `painted` in about 3s.
        wait(
            for: [readyReceived, viewChangedReceived, paintedReceived],
            timeout: 90, enforceOrder: true
        )

        XCTAssertFalse(viewChangedBeforeReady, "ready must precede the first viewChanged")
        XCTAssertEqual(
            firstView, .banner,
            "a fresh install with no stored decision must render the banner; page errors: \(errors)"
        )
        XCTAssertTrue(errors.isEmpty, "the page must boot with no error: \(errors)")
        XCTAssertTrue(host.isVisible, "a non-hidden viewChanged must reveal the window")
    }

    /// A `view` message sent before `init` produces an error, not a render
    /// (EMBEDDED.md section 4). Proving the shell surfaces it means a
    /// misintegration is visible rather than a blank sheet.
    @MainActor
    func testAViewBeforeInitSurfacesAnErrorFromThePage() throws {
        let errorReceived = expectation(description: "error")
        let host = WebViewHost(
            factory: CountingFactory(),
            bundle: try EmbeddedBundle.resolve(),
            loader: .inlineHTML(try EmbeddedBundle.inlinedPage())
        ) { event in
            // The MESSAGE is asserted, not just the case. The bundle emits
            // several distinct errors ("malformed host message", "no visitor
            // id: the shell did not seed one"), and index.html's own
            // window.onerror can surface a masked "Script error. @0" for an
            // unrelated throw — any of which would satisfy a bare
            // `if case .error`, letting this pass while proving nothing.
            if case .error(let text) = event, text.contains(Self.viewBeforeInit) {
                errorReceived.fulfill()
            }
        }
        host.prewarm()
        host.send(.view(.prefs))
        // 90s for the same cold-WebContent-process reason as the boot test.
        wait(for: [errorReceived], timeout: 90)
    }

    /// The literal string embedded.ts posts for this case, kept beside the
    /// test that asserts it so a rename in the bundle is a one-line fix.
    private static let viewBeforeInit = "view requested before init"

    /// Design §5: a navigation that FAILS must reach onError and reveal
    /// nothing. Both delegate callbacks are invoked directly, the way WebKit
    /// would, because neither is otherwise reachable from a hostless test
    /// target: under `.fileURL` a missing bundle is caught by prewarm's own
    /// guard before any navigation starts, and a present bundle hangs without
    /// ever failing (see PageLoader). A synthetic NSError is enough — what is
    /// under test is the host's reaction, not WebKit's error.
    @MainActor
    func testProvisionalNavigationFailureReportsAnErrorAndShowsNothing() throws {
        try assertNavigationFailureIsReported { host, webView, error in
            host.webView(webView, didFailProvisionalNavigation: nil, withError: error)
        }
    }

    /// The after-commit half of the same guarantee.
    @MainActor
    func testNavigationFailureAfterCommitReportsAnErrorAndShowsNothing() throws {
        try assertNavigationFailureIsReported { host, webView, error in
            host.webView(webView, didFail: nil, withError: error)
        }
    }

    @MainActor
    private func assertNavigationFailureIsReported(
        _ fail: (WebViewHost, WKWebView, Error) -> Void
    ) throws {
        var messages: [String] = []
        let host = WebViewHost(
            factory: CountingFactory(),
            bundle: try EmbeddedBundle.resolve(),
            // A trivial page: this test never waits on a real navigation, and
            // inlining the committed bundle would only add seconds to it.
            loader: .inlineHTML("<!doctype html><html><body></body></html>")
        ) { event in
            if case .error(let text) = event { messages.append(text) }
        }
        host.prewarm()

        let error = NSError(
            domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist,
            userInfo: [NSLocalizedDescriptionKey: "the requested file does not exist"]
        )
        fail(host, WKWebView(), error)

        XCTAssertEqual(messages.count, 1, "a load failure must report exactly once")
        XCTAssertTrue(
            messages.first?.contains("the requested file does not exist") ?? false,
            "the underlying error must survive into a non-empty message: \(messages)"
        )
        // The load-bearing half of design §5: never a broken or empty sheet.
        XCTAssertFalse(host.isVisible, "a failed load must never reveal the window")
    }

    /// A message that cannot be serialised must REPORT, not vanish.
    ///
    /// Reachable in production, which is the whole point: a corrupted on-disk
    /// config reaches `init` as opaque bytes that are not JSON, so
    /// `HostMessage.jsonString()` throws. The old `try?` swallowed it — a
    /// WebView existed, the page never received `init`, no notice ever
    /// appeared, and NOTHING reached onError. An invisible stall.
    @MainActor
    func testAMessageThatCannotBeSerialisedIsReportedRatherThanDropped() throws {
        var messages: [String] = []
        let host = WebViewHost(
            factory: CountingFactory(),
            bundle: try EmbeddedBundle.resolve(),
            loader: .inlineHTML("<!doctype html><html><body></body></html>")
        ) { event in
            if case .error(let text) = event { messages.append(text) }
        }
        host.prewarm()

        host.send(.init_(
            siteKey: "sk_test",
            apiBase: "https://api.example.com",
            visitorId: UUID().uuidString.lowercased(),
            // Exactly what a truncated or corrupted cache file looks like.
            config: Data("not json".utf8),
            prefs: nil,
            lang: nil
        ))

        XCTAssertEqual(messages.count, 1, "a serialisation failure must report exactly once")
        // The MESSAGE is asserted, not just the case: it has to name which
        // message the page will never receive, or the report is unactionable.
        XCTAssertTrue(
            messages.first?.contains("init") ?? false,
            "the report must name the message type that was lost: \(messages)"
        )
        XCTAssertTrue(
            host.pendingMessages.isEmpty,
            "an unserialisable message must not be queued for the page either"
        )
    }

    /// The one silence that is CORRECT: nothing was ever meant to be
    /// delivered before prewarm(), so there is nothing to report.
    @MainActor
    func testSendBeforePrewarmStaysSilent() throws {
        var messages: [String] = []
        let host = WebViewHost(
            factory: CountingFactory(), bundle: try EmbeddedBundle.resolve()
        ) { event in
            if case .error(let text) = event { messages.append(text) }
        }

        host.send(.view(.banner))

        XCTAssertTrue(messages.isEmpty, "send before prewarm is a no-op, not an error: \(messages)")
        XCTAssertTrue(host.pendingMessages.isEmpty)
    }

    /// Design §5: a WebView that fails to load reports through onError and
    /// shows NOTHING. An empty sheet would be worse than no sheet — the
    /// visitor would see a blank overlay with no way to act on it.
    ///
    /// An empty bundle has no index.html, so prewarm cannot navigate.
    @MainActor
    func testAMissingBundleReportsAnErrorAndShowsNothing() {
        let errorReceived = expectation(description: "error")
        var message: String?

        // Bundle.main inside an XCTest bundle contains no Resources/index.html.
        let host = WebViewHost(factory: CountingFactory(), bundle: .main) { event in
            if case .error(let text) = event {
                message = text
                errorReceived.fulfill()
            }
        }
        host.prewarm()

        wait(for: [errorReceived], timeout: 10)
        XCTAssertNotNil(message)
        XCTAssertFalse(host.isVisible, "a failed load must never reveal the window")
    }
}
