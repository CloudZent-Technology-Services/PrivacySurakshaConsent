import Foundation

/// Locates the LIBRARY target's resource bundle — the one holding
/// `Resources/index.html`, `cmp-embedded.js` and `i18n/`.
///
/// Top-level for the same reason `CountingFactory` is: every test that boots
/// the real page needs it, and Tasks 10 and 11 both do.
///
/// Why this exists at all, and why `Bundle.module` will not do:
/// the test target declares its own `resources: [.copy("Resources")]` (for the
/// renewal-cases.json fixture), so SwiftPM synthesises a `Bundle.module`
/// scoped to *this* target's bundle — `PrivacySurakshaConsent_PrivacySurakshaConsentTests
/// .bundle`, which contains only that fixture. The embedded page is in the
/// library target's sibling bundle, `PrivacySurakshaConsent_PrivacySurakshaConsent.bundle`.
/// A bare `Bundle.module` here silently resolves to the near-empty test bundle,
/// and `prewarm()` then reports "embedded bundle missing" instead of
/// navigating — which makes a boot test hang and, worse, makes a
/// page-error test pass for entirely the wrong reason. SwiftPM offers no
/// syntax to qualify `Bundle.module` by module name
/// (`PrivacySurakshaConsent.Bundle.module` does not compile), so this locates the
/// library bundle by the name SwiftPM assigns it (`<package>_<target>.bundle`),
/// built next to the test bundle in the same Products directory. Same
/// technique, and same reasoning, as `ResourcesTests.libraryResourceBundle()`.
enum EmbeddedBundle {

    /// Marker used only to find the directory the test bundle was built into.
    private final class Marker {}

    /// A thrown error rather than an XCTSkip: a missing library bundle is a
    /// build/environment defect, and skipping would let the suite go green
    /// with the page never having booted at all.
    static func resolve() throws -> Bundle {
        let bundleName = "PrivacySurakshaConsent_PrivacySurakshaConsent.bundle"
        let candidates = [
            Bundle.main.resourceURL,
            Bundle(for: Marker.self).resourceURL,
            Bundle(for: Marker.self).bundleURL.deletingLastPathComponent(),
            Bundle.main.bundleURL,
        ]
        for candidate in candidates {
            guard
                let url = candidate?.appendingPathComponent(bundleName),
                let bundle = Bundle(url: url),
                // Verified, not assumed: a name match with no index.html
                // inside is not the bundle we are looking for.
                bundle.url(forResource: "Resources/index.html", withExtension: nil) != nil
            else { continue }
            return bundle
        }
        throw NSError(
            domain: "EmbeddedBundle", code: 1,
            userInfo: [NSLocalizedDescriptionKey:
                "could not locate \(bundleName) with Resources/index.html alongside the test bundle — is scripts/sync-ios-assets.mjs run and the package resolved?"]
        )
    }

    /// The committed index.html with `cmp-embedded.js` substituted inline, for
    /// `PageLoader.inlineHTML`.
    ///
    /// Why any of this is necessary: in a hostless XCTest bundle
    /// `loadFileURL` neither completes nor fails — WebKit's WebContent process
    /// needs a sandbox extension for the granted directory and a test process
    /// with no UIApplication has none to issue. Verified three ways here: the
    /// bundle path hangs, a copy in the simulator's own tmp directory hangs
    /// identically, and a WKURLSchemeHandler hangs too. `loadHTMLString` is
    /// the one mechanism that runs, so a test that has to boot the real page
    /// inlines the bundle instead of fetching it as a subresource.
    ///
    /// This is still the REAL committed page and the REAL committed bundle —
    /// only the delivery differs. What it consequently does not cover is
    /// `loadFileURL` itself, and the real origin `loadFileURL` would give the
    /// document: `loadHTMLString(_:baseURL: nil)` leaves the page on an OPAQUE
    /// origin, where WebKit throws `SecurityError` from every Web Storage
    /// access. That costs this SDK nothing — the embedded bundle never touches
    /// Web Storage (`grep -c "localStorage\|sessionStorage\|indexedDB\|
    /// document.cookie" Resources/cmp-embedded.js` returns 0; prefs cross the
    /// boundary as `init`/`persist` and the shell owns storage) — and the page
    /// measurably boots all the way to `ready` -> `viewChanged` -> `painted`
    /// here, with a rendered shadow DOM. See PageLoader, consequence 2, for
    /// the one real cost of the opaque origin: masked exception messages.
    static func inlinedPage() throws -> String {
        let bundle = try resolve()
        guard let root = bundle.url(forResource: "Resources", withExtension: nil) else {
            throw NSError(domain: "EmbeddedBundle", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Resources/ not found in \(bundle.bundleURL.path)",
            ])
        }
        let html = try String(contentsOf: root.appendingPathComponent("index.html"), encoding: .utf8)
        let js = try String(contentsOf: root.appendingPathComponent("cmp-embedded.js"), encoding: .utf8)

        let tag = #"<script src="./cmp-embedded.js"></script>"#
        guard html.contains(tag) else {
            // A silent no-op substitution would leave the page scriptless and
            // the boot test would time out with nothing to point at.
            throw NSError(domain: "EmbeddedBundle", code: 3, userInfo: [
                NSLocalizedDescriptionKey:
                    "index.html no longer contains \(tag) — sync-ios-assets.mjs changed the entry point and EmbeddedBundle.inlinedPage must be updated to match",
            ])
        }
        return html.replacingOccurrences(of: tag, with: "<script>\n\(js)\n</script>")
    }
}
