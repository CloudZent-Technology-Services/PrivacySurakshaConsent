import Foundation
import UIKit
import WebKit

/// The seam conformance item 2 asserts against. Production uses
/// DefaultWebViewFactory; the suite counts creations to prove that a launch
/// with a valid stored decision creates NO WebView at all.
@MainActor
protocol WebViewFactory: AnyObject {
    func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView
}

@MainActor
final class DefaultWebViewFactory: WebViewFactory {
    func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView {
        WKWebView(frame: .zero, configuration: configuration)
    }
}

/// How the page's document gets into the WebView.
///
/// Production is always `.fileURL`: the page is a file in the app bundle, and
/// loading it from there is what gives the WebView a real origin and lets it
/// pull `cmp-embedded.js` as a sibling.
///
/// `.inlineHTML` exists for one reason. In a hostless XCTest bundle —
/// which is what a SwiftPM test target is — `loadFileURL` neither completes
/// nor fails. WebKit's WebContent process needs a sandbox extension for the
/// granted directory, and a test process with no UIApplication has none to
/// issue, so the navigation silently hangs: no `didFinish`, no
/// `didFailProvisionalNavigation`. Measured here, and it is not a path
/// problem — copying the bundle into the simulator's own tmp directory hangs
/// identically, and so does serving it through a WKURLSchemeHandler.
/// `loadHTMLString` is the only mechanism that works, so a test that has to
/// boot the real page inlines the bundle and passes it in.
///
/// Two consequences, stated plainly because both are easy to forget:
///
/// 1. A test using `.inlineHTML` proves the BRIDGE — the handler named
///    "compliant", the message shapes, host->page delivery and page->host
///    decode. It does NOT prove `loadFileURL`. That path is covered by the
///    failure test and by running on a device.
///
/// 2. `loadHTMLString(_:baseURL: nil)` gives the document an OPAQUE origin
///    (`location.origin === "null"`), and WebKit throws `SecurityError` from
///    every Web Storage access on an opaque origin — measured directly here.
///    That costs this SDK NOTHING, because the embedded bundle never touches
///    Web Storage: prefs cross the boundary as `init`/`persist` messages and
///    the SHELL owns storage (parent design, prefs/persistence;
///    src/embedded/storage-bridge.ts is an in-memory mirror with an explicit
///    "no cookies, no localStorage" contract). Verified, not assumed:
///    `grep -c "localStorage\|sessionStorage\|indexedDB\|document.cookie"
///    Resources/cmp-embedded.js` returns 0.
///
///    The page therefore boots FULLY under `.inlineHTML` — measured
///    `ready` -> `viewChanged` -> `painted`, with a rendered shadow DOM. It
///    is only a real origin, and `loadFileURL` itself, that this path cannot
///    prove.
///
///    One thing the opaque origin DOES cost, and it is a debugging trap: an
///    exception thrown from code that `evaluateJavaScript` invoked — which is
///    every host->page message, `init` included — reaches index.html's
///    `window.onerror` masked as `"Script error. @0"`, with no message and no
///    stack. A page-side bug then looks like a mysterious silent stall. To
///    unmask one, wrap `window.__compliantHostMessage` in the inlined page
///    and post `e.stack` yourself; the throw is not visible any other way.
///    Task 9's fix round found a malformed test config that way — the config
///    it passed to `init` omitted the required `languages` field, so
///    `resolveLang` threw inside the page's `init` handler right after
///    `ready` was posted, and every event downstream of it went missing. A
///    shell test that boots the real page must send a COMPLETE
///    PublicBannerConfig (see WebViewHostTests.fullConfig).
enum PageLoader {
    case fileURL
    case inlineHTML(String)
}

/// JOB 2 — prewarm and host the WebView.
///
/// Two rules that are easy to violate and expensive to get wrong:
///
/// 1. PREWARMING MEANS NAVIGATING, NOT ALLOCATING. Allocation measured 4.3 ms;
///    navigation to the first line of page JS measured 330.5 ms (parent
///    design 5). A host that allocates and waits has saved nothing.
///
/// 2. NEVER RELEASE THE WEBVIEW ON `hidden`. Hiding detaches; it does not
///    destroy. Releasing pays the full ~330 ms again on the next open, AND
///    loses the SECOND persist+decision pair that a successful consent POST
///    fires after viewChanged:'hidden' — the pair carrying recordId and
///    atServer, which receipt.ts and renewal.ts depend on
///    (EMBEDDED.md section 4).
@MainActor
final class WebViewHost: NSObject {

    private let factory: WebViewFactory
    private let bundle: Bundle
    private let loader: PageLoader
    private let onEvent: (PageEvent) -> Void

    private var webView: WKWebView?
    private var window: UIWindow?
    private var bridge: Bridge?

    /// Host->page messages that arrived before the document existed.
    ///
    /// The page's `__compliantHostMessage` queues messages that arrive before
    /// its own handler attaches, but that only helps once the document is
    /// there to hold the queue. Between `prewarm()` and the navigation
    /// finishing there is no document at all, and an `evaluateJavaScript` in
    /// that window is simply discarded — which silently loses `init`, and
    /// `init` is what the page emits `ready` from, so the whole session then
    /// hangs with no error anywhere. So the shell keeps its own queue.
    ///
    /// This is what makes `send(_:)` honestly safe to call at any time, and it
    /// waits on the DOCUMENT, never on `ready` — waiting on `ready` would give
    /// back the latency prewarming just bought.
    /// `private(set)` rather than `private` so the suite can assert on what
    /// the shell queued for the page, and in what order, without a live
    /// document. In a hostless XCTest bundle the navigation never finishes (see
    /// PageLoader), so everything sent stays here — which makes this the only
    /// available seam for "was `init` sent before `view`?".
    private(set) var pendingMessages: [String] = []
    private var documentReady = false

    private(set) var didCreateWebView = false

    var isVisible: Bool { window?.isHidden == false }

    /// `loader` defaults to `.fileURL`, so the three-argument form the rest of
    /// the SDK uses is the production one and nothing has to opt in to it.
    init(
        factory: WebViewFactory,
        bundle: Bundle,
        loader: PageLoader = .fileURL,
        onEvent: @escaping (PageEvent) -> Void
    ) {
        self.factory = factory
        self.bundle = bundle
        self.loader = loader
        self.onEvent = onEvent
        super.init()
    }

    /// Creates the WebView and NAVIGATES it. Idempotent: one WebView per
    /// session, always.
    func prewarm() {
        guard webView == nil else { return }

        let configuration = WKWebViewConfiguration()
        let created_bridge = Bridge(onEvent: { [weak self] event in
            self?.handle(event)
        })
        configuration.userContentController.add(created_bridge, name: Bridge.handlerName)
        bridge = created_bridge

        let created = factory.makeWebView(configuration: configuration)
        created.isOpaque = false
        created.backgroundColor = .clear
        created.scrollView.backgroundColor = .clear
        // Design 5: a WebView that fails to load must surface through
        // onError and show nothing — never a broken or empty sheet.
        created.navigationDelegate = self
        webView = created
        didCreateWebView = true

        switch loader {
        case .fileURL:
            guard
                let index = bundle.url(forResource: "Resources/index.html", withExtension: nil)
            else {
                onEvent(.error(message: "embedded bundle missing — run scripts/sync-ios-assets.mjs"))
                return
            }
            // Read access is granted to the whole Resources directory so the
            // page can load cmp-embedded.js and i18n/ as siblings.
            created.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())

        case .inlineHTML(let html):
            // baseURL is nil deliberately, and it is the ONLY value that
            // loads at all here — see PageLoader, consequence 2, for what
            // that costs and why every alternative was worse.
            created.loadHTMLString(html, baseURL: nil)
        }
    }

    /// Sends a host->page message. Safe to call before the bundle has finished
    /// parsing: __compliantHostMessage is installed at module load and queues
    /// anything that arrives early, draining the instant the page's handler
    /// attaches. A shell must NOT wait for `ready` before sending `init` —
    /// waiting would discard the whole benefit of prewarming.
    func send(_ message: HostMessage) {
        // No WebView yet means prewarm() has not run, and nothing was ever
        // meant to be delivered — the only genuinely silent case here.
        guard webView != nil else { return }

        let json: String
        do {
            json = try message.jsonString()
        } catch {
            // Was a `try?`. A throw here is reachable in production: a
            // corrupted on-disk config reaches `init` as opaque bytes that
            // are not JSON, and swallowing the throw produced a WebView that
            // never received `init`, a notice that never appeared, and
            // NOTHING in onError — an invisible stall. Reported instead.
            onEvent(.error(message:
                "host->page \(message.typeName) message could not be serialised, so the page "
                + "will never receive it: \(error.localizedDescription)"))
            return
        }

        guard documentReady else {
            pendingMessages.append(json)
            return
        }
        deliver(json)
    }

    private func deliver(_ json: String) {
        webView?.evaluateJavaScript("window.__compliantHostMessage(\(json))")
    }

    private func drainPendingMessages() {
        let queued = pendingMessages
        pendingMessages.removeAll()
        for json in queued { deliver(json) }
    }

    /// Shows or hides the notice. NEVER releases the WebView.
    func setVisible(_ visible: Bool) {
        if visible { ensureWindow() }
        window?.isHidden = !visible
    }

    /// Test-only. Conformance item 10 reads the rendered `dir` attribute to
    /// prove Urdu renders right-to-left — the question is whether the NOTICE
    /// is RTL, which only the DOM can answer.
    func evaluateForTesting(_ javaScript: String, completion: @escaping (Any?) -> Void) {
        guard let webView else { return completion(nil) }
        webView.evaluateJavaScript(javaScript) { result, _ in completion(result) }
    }

    private func handle(_ event: PageEvent) {
        // viewChanged drives visibility and nothing else. In particular it
        // never tears anything down — see the class docblock, rule 2.
        if case .viewChanged(let view) = event {
            setVisible(view != .hidden)
        }
        onEvent(event)
    }

    /// The SDK owns its own window so the customer supplies no view controller
    /// and does no presentation plumbing (design 3.3). One level below .alert,
    /// so a system alert still wins.
    private func ensureWindow() {
        guard window == nil, let webView else { return }

        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first

        let created: UIWindow = scene.map { UIWindow(windowScene: $0) }
            ?? UIWindow(frame: UIScreen.main.bounds)

        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        controller.view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: controller.view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
        ])

        created.rootViewController = controller
        created.windowLevel = .alert - 1
        created.backgroundColor = .clear
        created.isHidden = true
        window = created
    }
}

// MARK: - Load failures

/// Design §5: "WebView fails to load -> onError, show no banner, leave state
/// denied. Never show a broken or empty sheet."
///
/// Both callbacks are needed. `didFailProvisionalNavigation` covers a failure
/// before any content is committed — the file URL is wrong, the bundle is
/// missing — which is the likely case here. `didFail` covers a failure after
/// commit. Neither shows anything: the window stays hidden, because it is only
/// ever revealed by a `viewChanged` the page will now never send.
extension WebViewHost: WKNavigationDelegate {

    /// The document now exists, so anything `send(_:)` queued before it did
    /// can go out. Deliberately NOT gated on the page's `ready` — the page
    /// installs `__compliantHostMessage` at module load and queues from there,
    /// so `init` can go out immediately, which is the whole point of
    /// prewarming.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        documentReady = true
        drainPendingMessages()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        onEvent(.error(message: "WebView failed to load: \(error.localizedDescription)"))
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        onEvent(.error(message: "WebView navigation failed: \(error.localizedDescription)"))
    }
}
