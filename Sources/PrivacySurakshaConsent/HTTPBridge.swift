import Foundation

/// Performs the API calls the page asks for via `httpRequest`, and injects
/// row 384's app-key header.
///
/// The page never fetches anything itself — every call is routed through here
/// (api-bridge.ts), which is exactly why there is ONE place to add the header
/// rather than one per call site. Row 384's eventual attestation header lands
/// in this same spot.
struct HTTPBridge {

    /// Row 384. Value shape: "app_" + 32 lowercase hex.
    static let appKeyHeader = "X-Compliant-App"

    private let apiBase: URL
    private let appKey: String?
    private let session: HTTPPerforming

    init(apiBase: URL, appKey: String?, session: HTTPPerforming) {
        self.apiBase = apiBase
        self.appKey = appKey
        self.session = session
    }

    func perform(_ spec: HTTPRequestSpec) async -> HTTPBridgeResult {
        // The path comes from the PAGE. protocol.ts documents it as "always
        // absolute and API-relative", but a document is not an invariant, and
        // URL(string:relativeTo:) honours an absolute or scheme-relative
        // string by resolving to THAT host — which would send row 384's
        // X-Compliant-App header to it. Enforced here, at the trust boundary,
        // for the same reason CatalogReader.isSafeLocale enforces the locale
        // shape rather than trusting the page's string.
        guard let url = resolvedURL(for: spec.path) else {
            // "http", not "network": nothing was attempted and nothing
            // failed in transport — this shell REFUSED the request, which the
            // page must treat as definitive rather than retry.
            return .failure("http")
        }

        var request = URLRequest(url: url)
        request.httpMethod = spec.method

        // Sent on EVERY bridged request, not only the two routes that enforce
        // it today. Scoping it to a hardcoded path list would mean four shells
        // to edit the day a third route starts enforcing, and an unnecessary
        // header on an unenforced route costs nothing.
        //
        // nil means send nothing — correct against a site that has registered
        // no apps, which is how an integration is tested before registration.
        if let appKey {
            request.setValue(appKey, forHTTPHeaderField: Self.appKeyHeader)
        }

        if let body = spec.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure("network") }
            guard (200..<300).contains(http.statusCode) else {
                // Includes row 384's 403. The page treats "http" as a
                // definitive server refusal rather than something to retry.
                return .failure("http")
            }
            return .ok(data)
        } catch {
            return .failure("network")
        }
    }

    /// nil means REFUSE — the path is not API-relative, or resolves off
    /// `apiBase`'s host.
    private func resolvedURL(for path: String) -> URL? {
        // Exactly one leading slash. No leading slash at all is not
        // API-relative; "//evil.example.com/x" is scheme-relative and
        // resolves to that host, keeping only apiBase's scheme.
        guard path.hasPrefix("/"), !path.hasPrefix("//") else { return nil }

        // Redundant with the leading-slash check above in practice — a
        // string starting with exactly one "/" cannot itself parse a
        // scheme — but kept as a second, independent guard against an
        // absolute URL carrying its own scheme and host, so this file
        // doesn't rely on the leading-slash check alone to catch it.
        guard URL(string: path)?.scheme == nil else { return nil }

        guard let resolved = URL(string: path, relativeTo: apiBase)?.absoluteURL else {
            return nil
        }

        // A second, STRUCTURAL check on the resolved URL rather than the
        // string, so anything the prefix checks missed is still caught: the
        // app key must never leave apiBase's host.
        guard let host = resolved.host, host == apiBase.host else { return nil }

        return resolved
    }
}
