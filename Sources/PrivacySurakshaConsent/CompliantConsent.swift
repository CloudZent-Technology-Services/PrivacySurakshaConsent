import Foundation
import UIKit

/// The SDK's public entry point.
///
///     CompliantConsent.start(.init(
///         siteKey: "sk_...",
///         apiBase: URL(string: "https://api.privacysuraksha.com")!,
///         appKey:  "app_..."
///     ))
///
/// Call it from application(_:didFinishLaunchingWithOptions:). It returns
/// immediately; everything after the Keychain read is asynchronous.
public enum CompliantConsent {

    /// Bumped by hand at release time.
    public static let sdkVersion = "0.1.0"

    /// Reported failures the customer can act on: a missing config with no
    /// cache, a Keychain problem, a page error, a signal writer that threw.
    public static var onError: ((Error) -> Void)?

    @MainActor private static var runtime: CompliantRuntime?

    /// Test-only seam. `runtime` is process-wide static state with no public
    /// accessor, so the suite has no other way to assert that a second
    /// `start(_:)` did not replace it, or to put the process back the way it
    /// found it. Internal — invisible outside `@testable import`.
    @MainActor static var runtimeForTesting: CompliantRuntime? {
        get { runtime }
        set { runtime = newValue }
    }

    public static func start(_ configuration: CompliantConfiguration) {
        Task { @MainActor in
            // One WebView per session, always — and one runtime, since the
            // runtime OWNS the WebViewHost. A second start() (plausible from
            // didFinishLaunchingWithOptions and a scene delegate both calling
            // it) would otherwise build a second host, re-pay the ~330 ms
            // prewarm, and could put two notices on screen.
            //
            // The check lives INSIDE the @MainActor block, not around the
            // Task: two back-to-back start() calls each spawn a Task, and only
            // a check that runs on the actor BEFORE constructing anything can
            // serialise them. Both Tasks hop to the main actor; the first sets
            // `runtime`, the second then sees it and returns.
            guard runtime == nil else {
                onError?(NSError(
                    domain: "com.compliant.consent", code: 3,
                    userInfo: [NSLocalizedDescriptionKey:
                        "CompliantConsent.start(_:) ignored: it has already been called. One "
                        + "consent session per process — call it once, from "
                        + "application(_:didFinishLaunchingWithOptions:)."]
                ))
                return
            }

            let created = CompliantRuntime(
                configuration: configuration,
                session: URLSession.shared,
                prefsStore: PrefsStore(),
                deviceIdentifier: DeviceIdentifier(),
                webViewFactory: DefaultWebViewFactory(),
                cacheDirectory: Self.defaultCacheDirectory(),
                now: { Date() }
            )
            created.onError = { onError?($0) }
            runtime = created
            await created.start()
        }
    }

    /// The app's "Privacy settings" entry point.
    ///
    /// `.hidden` is deliberately refused: it is an outbound state the page
    /// reports, and asking for it would produce a viewChanged:'hidden' with
    /// no preceding visible view.
    public static func show(_ view: CompliantView) {
        Task { @MainActor in
            // The `.hidden` refusal lives on the actor too, not as a bare
            // guard before the Task: every other onError report in this file
            // delivers on the main actor, and a customer calling show() off
            // the main thread deserves that same guarantee for every case,
            // not all but one of them.
            //
            // Refusing `.hidden` is correct; refusing it INVISIBLY is not —
            // it is a public case of a public enum, so any developer can
            // reach it, and this is the same silent no-op the nil-runtime
            // guard below was added to close.
            guard view != .hidden else {
                onError?(NSError(
                    domain: "com.compliant.consent", code: 2,
                    userInfo: [NSLocalizedDescriptionKey:
                        "show(.hidden) ignored: .hidden is an outbound state the page reports, "
                        + "not a view you can request. Pass .banner or .prefs; the page hides "
                        + "itself."]
                ))
                return
            }
            // Mirrors CompliantRuntime.show's own "no config yet" report —
            // same cause (nothing has been resolved), just caught one layer
            // higher: start() has not even been called, so there is no
            // runtime to ask. Without this the public API silently no-ops
            // on exactly the developer error this whole path exists to
            // report — the same bug this file's fix round already closed
            // for the "started but not yet resolved" case.
            guard let runtime else {
                onError?(NSError(
                    domain: "com.compliant.consent", code: 2,
                    userInfo: [NSLocalizedDescriptionKey:
                        "show(\(view.rawValue)) ignored: CompliantConsent.start(_:) has not been "
                        + "called yet."]
                ))
                return
            }
            runtime.show(view)
        }
    }

    private static func defaultCacheDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("CompliantConsent", isDirectory: true)
    }
}

/// The testable core. `CompliantConsent.start` delegates to this, with every
/// collaborator injectable so the conformance suite can drive it.
@MainActor
final class CompliantRuntime {

    var onError: ((Error) -> Void)?

    /// Recorded so a test can assert the visitor id sent on init is a UUID.
    private(set) var lastInitVisitorId: String?

    /// The config `start()` resolved, retained so `show(_:)` can lazily
    /// prewarm and send `init` on a launch where JOB 1 said no DECISION was
    /// needed and therefore created no WebView.
    ///
    /// Job 1 answers "is a consent decision needed", NOT "is the config
    /// available". Conflating the two is what made `show(_:)` a silent no-op
    /// on every launch after the first: the config was resolved, then thrown
    /// away with the early return, so the app's "Privacy settings" button did
    /// nothing at all. So the config is resolved and retained BEFORE the gate
    /// is consulted, and the gate only decides whether to auto-prewarm.
    private(set) var resolvedConfig: Data?

    /// Resolved at most once per session. The Keychain read is the one
    /// synchronous cost on the start path, and a lazy `show(_:)` must not pay
    /// it again when `start()` already did.
    private var resolvedVisitorId: String?

    /// Exposed internally so the suite can assert on what the shell queued
    /// for the page without a live document. Nothing here is public.
    private(set) var host: WebViewHost!

    private let configuration: CompliantConfiguration
    private let session: HTTPPerforming
    private let prefsStore: PrefsStore
    private let deviceIdentifier: DeviceIdentifier
    private let cacheDirectory: URL
    private let now: () -> Date
    private let httpBridge: HTTPBridge
    private let catalogReader = CatalogReader()

    init(
        configuration: CompliantConfiguration,
        session: HTTPPerforming,
        prefsStore: PrefsStore,
        deviceIdentifier: DeviceIdentifier,
        webViewFactory: WebViewFactory,
        cacheDirectory: URL,
        now: @escaping () -> Date
    ) {
        self.configuration = configuration
        self.session = session
        self.prefsStore = prefsStore
        self.deviceIdentifier = deviceIdentifier
        self.cacheDirectory = cacheDirectory
        self.now = now
        self.httpBridge = HTTPBridge(
            apiBase: configuration.apiBase, appKey: configuration.appKey, session: session
        )
        self.host = WebViewHost(
            factory: webViewFactory, bundle: .module,
            onEvent: { [weak self] event in self?.handle(event) }
        )
    }

    func start() async {
        let cache = ConfigCache(
            siteKey: configuration.siteKey, apiBase: configuration.apiBase,
            session: session, directory: cacheDirectory
        )

        // RULE 3 — "on later launches, read disk first, then refresh in the
        // background". This read is synchronous and cheap, and it is the whole
        // point: a launch with a warm cache must never sit on the network
        // before it can decide whether to show a notice. A slow or dead
        // network then costs the notice nothing.
        let onDisk = cache.cached()

        let config: Data?
        if let onDisk {
            config = onDisk
            // The refresh is for the NEXT launch only, so it is deliberately
            // unawaited and detached: nothing on this launch depends on it.
            //
            // Its failure is NOT reported. A refresh that fails while a valid
            // disk copy already answered the gate is rule 4 working exactly as
            // designed, and reporting it would train customers to ignore
            // onError. Rule 5's genuine "no config, no cache" case can only
            // arise in the awaited branch below, which is where it is reported.
            Task.detached { _ = await cache.load() }
        } else {
            // RULES 4 and 5 — first launch, nothing on disk. There is
            // genuinely nothing to gate on without the network, so this one
            // path must await. `load()` itself falls back to the cache, which
            // is why a cache miss here is a real rule 5.
            let (fetched, error) = await cache.load()
            if fetched == nil, let error { onError?(error) }
            config = fetched
        }

        // Rule 5: no config and no cache means show NOTHING and record
        // nothing. Never invent a notice.
        guard let config else { return }

        // Retained BEFORE the gate, because `show(_:)` needs it even on the
        // launches the gate stops — see `resolvedConfig`.
        resolvedConfig = config

        // JOB 1. When a valid decision already exists this returns BEFORE any
        // WebView is created — which is every launch after the first, and is
        // the whole latency argument.
        guard case .needed = ConsentGate.decide(
            prefs: prefsStore.prefs, config: config, now: now()
        ) else { return }

        prewarmAndInitialise(config: config)
    }

    /// The app's "Privacy settings" entry point.
    ///
    /// On any launch after the first, JOB 1 stops `start()` before a WebView
    /// exists. So this has to be able to bring the page up on its own rather
    /// than assume `start()` already did — otherwise it silently does nothing,
    /// which is the exact bug this replaced.
    func show(_ view: CompliantView) {
        // No config was ever resolved: developer error (show before start), or
        // a first launch that was offline with an empty cache. Either way there
        // is nothing legitimate to render, and rule 5 forbids inventing a
        // notice — so report it and show nothing. A broken or empty sheet is
        // never an acceptable outcome (design 5).
        guard let resolvedConfig else {
            onError?(NSError(
                domain: "com.compliant.consent", code: 2,
                userInfo: [NSLocalizedDescriptionKey:
                    "show(\(view.rawValue)) ignored: no consent config is available yet. "
                    + "Call CompliantConsent.start(_:) first, and note that a first launch "
                    + "with no network and no cached config has no notice to show."]
            ))
            return
        }

        // `didCreateWebView` is the session's "has prewarm() run" flag, and it
        // is one WebView per session — prewarm() is idempotent, so this stays
        // correct even if it were called twice.
        if !host.didCreateWebView {
            prewarmAndInitialise(config: resolvedConfig)
        }

        // Ordering is safe with no waiting logic: WebViewHost.send queues
        // host->page messages until the document exists and drains them in
        // order, so `init` is always delivered before this `view`.
        host.send(.view(view))
    }

    /// Creates the WebView, navigates it, and sends `init`. Shared by the
    /// auto-launch path and the lazy `show(_:)` path so the two can never
    /// drift apart on what the page is told.
    private func prewarmAndInitialise(config: Data) {
        let visitorId = visitorIdentifier()

        host.prewarm()
        // Sent immediately, without waiting for `ready`: the page queues
        // anything that arrives before its handler attaches, and waiting
        // would discard the whole benefit of prewarming.
        host.send(.init_(
            siteKey: configuration.siteKey,
            apiBase: configuration.apiBase.absoluteString,
            visitorId: visitorId,
            config: config,
            prefs: prefsStore.prefs,
            lang: prefsStore.lang
        ))
    }

    /// The stable per-install visitor id, read from the Keychain once per
    /// session. A Keychain failure is reported and the fallback id is used —
    /// the notice still has to work.
    private func visitorIdentifier() -> String {
        if let resolvedVisitorId { return resolvedVisitorId }
        let (visitorId, keychainError) = deviceIdentifier.current()
        if let keychainError { onError?(keychainError) }
        resolvedVisitorId = visitorId
        lastInitVisitorId = visitorId
        return visitorId
    }

    /// Internal so the suite can drive individual events without a live page.
    func handle(_ event: PageEvent) {
        switch event {
        case let .persist(prefs, lang):
            // Persisted BEFORE anything else is acknowledged: this is the only
            // durable copy, since the page's mirror dies with the WebView.
            prefsStore.write(prefs: prefs, lang: lang)

        case let .decision(_, signals):
            // JOB 4. A throwing writer is reported and swallowed — a missing
            // Consent Mode call must never cost the consent record, which is
            // the legally meaningful artefact and is already persisted.
            do {
                try configuration.signalWriter?.write(ConsentModeMapping.normalise(signals))
            } catch {
                onError?(error)
            }

        case let .catalogRequest(lang):
            host.send(.catalog(lang: lang, catalog: catalogReader.catalog(for: lang)))

        case let .httpRequest(spec):
            let bridge = httpBridge
            Task { [weak self] in
                let result = await bridge.perform(spec)
                await MainActor.run {
                    self?.host.send(.httpResult(id: spec.id, result: result))
                }
            }

        case let .error(message):
            onError?(NSError(
                domain: "com.compliant.consent", code: 1,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))

        case .ready, .painted, .viewChanged:
            // viewChanged's visibility handling lives in WebViewHost, which
            // acts on it before forwarding. Nothing further to do here.
            break
        }
    }
}
