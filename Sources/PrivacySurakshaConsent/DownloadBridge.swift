import Foundation

/// Answers the page's `download` messages: performs the request (same
/// trust boundary and app-key header as HTTPBridge) and writes the
/// response body to a file in [directory] instead of decoding it — the
/// response can be a binary PDF.
struct DownloadBridge {
    enum Outcome {
        case ok(fileURL: URL, mimeType: String)
        case failure(String, status: Int? = nil)
    }

    private let apiBase: URL
    private let appKey: String?
    private let session: HTTPPerforming
    private let directory: URL

    init(apiBase: URL, appKey: String?, session: HTTPPerforming, directory: URL) {
        self.apiBase = apiBase
        self.appKey = appKey
        self.session = session
        self.directory = directory
    }

    func perform(_ spec: DownloadSpec) async -> Outcome {
        guard let url = resolvedURL(for: spec.path) else { return .failure("http") }

        var request = URLRequest(url: url)
        request.httpMethod = spec.method
        if let appKey {
            request.setValue(appKey, forHTTPHeaderField: HTTPBridge.appKeyHeader)
        }
        if let body = spec.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure("network") }
            guard (200..<300).contains(http.statusCode) else {
                return .failure("http", status: http.statusCode)
            }
            let filename = Self.filename(from: http, fallback: spec.filename)
            let mimeType = http.value(forHTTPHeaderField: "Content-Type")?
                .split(separator: ";").first.map(String.init) ?? "application/octet-stream"
            let fileURL = directory.appendingPathComponent(filename)
            try data.write(to: fileURL, options: .atomic)
            return .ok(fileURL: fileURL, mimeType: mimeType)
        } catch {
            return .failure("network")
        }
    }

    /// Identical to HTTPBridge.resolvedURL — see its comments for why each check exists.
    private func resolvedURL(for path: String) -> URL? {
        guard path.hasPrefix("/"), !path.hasPrefix("//") else { return nil }
        guard URL(string: path)?.scheme == nil else { return nil }
        guard let resolved = URL(string: path, relativeTo: apiBase)?.absoluteURL else { return nil }
        guard let host = resolved.host, host == apiBase.host else { return nil }
        return resolved
    }

    private static func filename(from response: HTTPURLResponse, fallback: String) -> String {
        guard
            let disposition = response.value(forHTTPHeaderField: "Content-Disposition"),
            let range = disposition.range(of: #"filename="?([^";]+)"?"#, options: .regularExpression)
        else { return fallback }
        return disposition[range]
            .replacingOccurrences(of: "filename=", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}
