import XCTest
@testable import PrivacySurakshaConsent

/// The PUBLIC `CompliantConsent` type's own error-report paths.
///
/// Every other test in this suite drives `CompliantRuntime` directly, which is
/// deliberate — the public wrapper's `runtime` and `onError` are static, so
/// they are shared by the whole test process and a careless test pollutes
/// every later one. That avoidance left the public surface itself untested,
/// including the nil-runtime report added specifically to close a silent
/// no-op.
///
/// Discipline every test here follows, without exception:
///
///  * `onError` is saved and restored in a `defer`, so nothing here can
///    redirect another test's error reporting.
///  * `runtimeForTesting` is saved and restored in a `defer` too. It is an
///    internal test-only accessor on `CompliantConsent` — without it there is
///    no way to observe whether a second `start(_:)` replaced the runtime, and
///    no way to put the process back.
///  * `CompliantConsent.start(_:)` is NEVER called with a real configuration
///    here. It would wire `URLSession.shared` (the public API takes no session
///    seam) and leave a live runtime behind for the rest of the process. The
///    duplicate-start test below instead seeds `runtime` and asserts the guard
///    refuses to overwrite it — see that test for exactly what it does and
///    does not prove.
final class CompliantConsentPublicAPITests: XCTestCase {

    /// The report arrives from inside a `Task { @MainActor in ... }` for the
    /// nil-runtime case, so every assertion waits rather than reading a var.
    private func captureError(
        timeout: TimeInterval = 5, _ body: () -> Void
    ) -> Error? {
        let reported = expectation(description: "onError")
        var captured: Error?
        let previous = CompliantConsent.onError
        defer { CompliantConsent.onError = previous }

        CompliantConsent.onError = { error in
            guard captured == nil else { return }
            captured = error
            reported.fulfill()
        }
        body()
        wait(for: [reported], timeout: timeout)
        return captured
    }

    /// `show(_:)` before `start(_:)` must REPORT. This is the exact fix added
    /// after Task 10's re-review — "the public API silently no-ops on exactly
    /// the developer error this whole path exists to report" — and until now
    /// it had zero verification.
    @MainActor
    func testShowBeforeStartReportsThatStartWasNeverCalled() {
        let previousRuntime = CompliantConsent.runtimeForTesting
        defer { CompliantConsent.runtimeForTesting = previousRuntime }
        // Fresh process state, regardless of what any earlier test did.
        CompliantConsent.runtimeForTesting = nil

        let error = captureError { CompliantConsent.show(.banner) }

        let message = (error as NSError?)?.localizedDescription ?? ""
        XCTAssertTrue(
            message.contains("start(_:)"),
            "the report must name the call the developer skipped: \(message)"
        )
        XCTAssertTrue(
            message.contains("banner"),
            "the report must name the view that was refused: \(message)"
        )
    }

    /// Finding 6. Refusing `.hidden` is correct — it is an outbound state the
    /// page reports, and asking for it would produce a viewChanged:'hidden'
    /// with no preceding visible view. Refusing it INVISIBLY is not: it is a
    /// public case of a public enum, reachable by any developer.
    @MainActor
    func testShowHiddenIsRefusedWithAReport() {
        let previousRuntime = CompliantConsent.runtimeForTesting
        defer { CompliantConsent.runtimeForTesting = previousRuntime }
        CompliantConsent.runtimeForTesting = nil

        let error = captureError { CompliantConsent.show(.hidden) }

        let message = (error as NSError?)?.localizedDescription ?? ""
        XCTAssertTrue(
            message.contains("hidden"),
            "the report must say what was refused: \(message)"
        )
    }

    /// Finding 7. A second `start(_:)` must not build a second runtime — the
    /// runtime OWNS the WebViewHost, so a second one means a second WebView,
    /// the ~330 ms prewarm paid twice, and potentially two notices. "One
    /// WebView per session, always."
    ///
    /// WHAT THIS PROVES, precisely: with a runtime already present, `start(_:)`
    /// leaves that exact instance in place (asserted by identity) and reports
    /// the duplicate. The guard runs before `CompliantRuntime` is constructed,
    /// so nothing is built and no network is touched — which is why this test
    /// needs no URLSession stub.
    ///
    /// WHAT IT DOES NOT PROVE: the two-back-to-back-calls race from a genuinely
    /// empty state. That would require letting the first call construct a real
    /// runtime against `URLSession.shared` — the public API exposes no session
    /// seam — and would leave a live runtime behind for every later test in the
    /// process. The race safety instead rests on the guard living inside the
    /// `@MainActor` Task body, before construction: both Tasks hop to the main
    /// actor, so the second observes the first's assignment.
    @MainActor
    func testASecondStartDoesNotReplaceTheRuntime() {
        let previousRuntime = CompliantConsent.runtimeForTesting
        defer { CompliantConsent.runtimeForTesting = previousRuntime }

        let existing = Self.makeIsolatedRuntime()
        CompliantConsent.runtimeForTesting = existing

        let error = captureError {
            CompliantConsent.start(.init(
                siteKey: "sk_second", apiBase: URL(string: "https://api.example.com")!
            ))
        }

        XCTAssertTrue(
            CompliantConsent.runtimeForTesting === existing,
            "a second start() must leave the first session's runtime untouched"
        )
        let message = (error as NSError?)?.localizedDescription ?? ""
        XCTAssertTrue(
            message.contains("already been called"),
            "the duplicate must be reported, not silently ignored: \(message)"
        )
    }

    /// A runtime wired entirely to test doubles: a stub session that answers
    /// nothing, a throwaway UserDefaults suite, a throwaway Keychain service
    /// and a counting WebView factory. Nothing here touches the network, the
    /// real prefs domain, or the real Keychain entry — it exists only to be a
    /// non-nil object the guard under test can refuse to overwrite.
    @MainActor
    private static func makeIsolatedRuntime() -> CompliantRuntime {
        CompliantRuntime(
            configuration: CompliantConfiguration(
                siteKey: "sk_existing", apiBase: URL(string: "https://api.example.com")!
            ),
            session: StubHTTP(alwaysOffline: true),
            prefsStore: PrefsStore(suiteName: "com.compliant.tests.\(UUID().uuidString)"),
            deviceIdentifier: DeviceIdentifier(service: "com.compliant.tests.\(UUID().uuidString)"),
            webViewFactory: CountingFactory(),
            cacheDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true),
            now: { Date() }
        )
    }
}
