import Foundation

/// The seam that makes offline behaviour testable without a device toggle.
/// URLSession conforms as-is.
protocol HTTPPerforming: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPPerforming {}

enum ConfigCacheError: Error {
    case noCacheAndNoNetwork
    case badStatus(Int)
    case malformedBody
}

/// Parent design 3.5, verbatim:
///
///   1. On start(), fetch GET /api/v1/config/:siteKey
///   2. Write the response to disk
///   3. On later launches, read disk first, then refresh in the background
///   4. Network fails, cache exists -> use the cache
///   5. Network fails, no cache    -> show NO banner and record NO consent
///
/// Rule 5 is not a customer-visible failure to recover from. Do not invent a
/// notice: an app with no notice available must process nothing
/// non-essential, which is exactly the state "no consent" describes.
final class ConfigCache: @unchecked Sendable {

    private let siteKey: String
    private let apiBase: URL
    private let session: HTTPPerforming
    private let directory: URL

    init(siteKey: String, apiBase: URL, session: HTTPPerforming, directory: URL) {
        self.siteKey = siteKey
        self.apiBase = apiBase
        self.session = session
        self.directory = directory
    }

    /// Keyed by site key so two sites in one app never share a cache file.
    private var cacheURL: URL {
        directory.appendingPathComponent("config-\(siteKey).json")
    }

    /// The cached config, or nil. Synchronous and cheap — this is what rule 3
    /// reads before any network work starts.
    func cached() -> Data? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        // The SAME check fetch() applies before writing. `fetch()` guarding
        // the write is not enough on its own: a file truncated by a crash
        // mid-write, or corrupted by anything else on disk, is read back here
        // and trusted. It then reaches `init` as opaque bytes that
        // HostMessage.jsonString cannot serialise, and the page never gets
        // `init` at all. A corrupt file is therefore treated as a cache MISS,
        // which drops start() onto the awaited network path (rules 4/5) where
        // a real failure is reported.
        guard Self.isValidJSON(data) else { return nil }
        return data
    }

    private static func isValidJSON(_ data: Data) -> Bool {
        (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    /// Rules 1, 2, 4 and 5. Returns the config to render with, plus an error
    /// worth reporting to the customer's `onError`.
    ///
    /// A cache hit after a network failure is NOT an error: that is rule 4
    /// working exactly as designed, and reporting it would train customers to
    /// ignore onError.
    func load() async -> (config: Data?, error: Error?) {
        do {
            let fresh = try await fetch()
            try? write(fresh)
            return (fresh, nil)
        } catch {
            if let cached = cached() {
                return (cached, nil)
            }
            // A response DID come back — a bad status or an unparsable body —
            // so surface that specific cause rather than collapsing it into
            // "no network". Whoever reads onError for diagnostics needs to
            // tell "the server is down" apart from "the server answered with
            // garbage"; only a genuine transport failure (anything that
            // isn't one of fetch()'s own typed errors) is truly "no network".
            if error is ConfigCacheError {
                return (nil, error)
            }
            return (nil, ConfigCacheError.noCacheAndNoNetwork)
        }
    }

    private func fetch() async throws -> Data {
        var url = apiBase
        url.appendPathComponent("api/v1/config/\(siteKey)")

        let (data, response) = try await session.data(for: URLRequest(url: url))

        guard let http = response as? HTTPURLResponse else { throw ConfigCacheError.malformedBody }
        guard (200..<300).contains(http.statusCode) else {
            throw ConfigCacheError.badStatus(http.statusCode)
        }
        // Validated before caching: a 200 carrying a non-JSON body written to
        // disk would be read back and trusted on the next launch. `cached()`
        // applies the identical check on the way back out.
        guard Self.isValidJSON(data) else {
            throw ConfigCacheError.malformedBody
        }
        return data
    }

    private func write(_ data: Data) throws {
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )
        try data.write(to: cacheURL, options: .atomic)

        // A cached notice is reconstructible from the server and has no
        // business consuming a customer's iCloud quota.
        var url = cacheURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
