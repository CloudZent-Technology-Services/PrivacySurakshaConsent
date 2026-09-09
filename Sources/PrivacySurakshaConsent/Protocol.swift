import Foundation

/// The wire channel name. Copied from CHANNEL in
/// packages/banner/src/embedded/protocol.ts.
let compliantChannel = "compliant-embedded"

/// The page's visible view. Mirrors the `View` union in
/// packages/banner/src/types.ts.
///
/// This is public because `CompliantConsent.show(_:)` takes it, but note that
/// the public API deliberately does not let a customer ASK for `.hidden` —
/// see Configuration.swift, where the public-facing subset is defined.
public enum CompliantView: String, Sendable {
    case banner
    case prefs
    case dsr
    case grievance
    case ageGate = "age_gate"
    case hidden
}

/// Consent Mode v2 signal state. Mirrors `SignalState` in
/// packages/banner/src/consent-mode.ts, which is the two strings
/// "granted" | "denied" — not a boolean, so a third state stays a protocol
/// change rather than a silent Swift-side widening.
public enum ConsentSignalState: String, Sendable {
    case granted
    case denied
}

/// What the page asked the shell to fetch.
struct HTTPRequestSpec {
    let id: String
    let method: String
    /// Always absolute and API-relative, e.g. "/api/v1/consent".
    let path: String
    /// Present only on some POSTs; a GET never carries one.
    let body: Data?
}

/// The result the shell hands back, matching `ApiResult<unknown>`.
enum HTTPBridgeResult {
    case ok(Data)
    /// "http" or "network" — the only two values the page understands.
    /// `status` is populated only for an "http" failure that actually
    /// reached the server (never for a locally-refused path, and never for
    /// "network") — see packages/banner/src/types.ts's ApiResult, which this
    /// mirrors. It is how the page tells a 404 ("nothing published yet")
    /// apart from a real failure.
    case failure(String, status: Int? = nil)
}

/// What the page asked the shell to fetch and hand to the user via the share
/// sheet. Mirrors `DownloadEvent` in packages/banner/src/embedded/protocol.ts.
struct DownloadSpec {
    let id: String
    let method: String
    let path: String
    let body: Data?
    let filename: String
}

/// Mirrors HTTPBridgeResult but carries no successful payload — the shell
/// shares the file itself; the page only needs to know pass/fail.
enum DownloadBridgeResult {
    case ok
    case failure(String, status: Int? = nil)
}

enum ProtocolError: Error {
    case malformedJSON
    case unknownEventType(String)
    case missingField(String)
}

// MARK: - Host -> page

/// Messages the shell sends. Every one carries `source` so the page's
/// `isHostMessage` accepts it; a message without it is silently ignored.
enum HostMessage {
    case init_(
        siteKey: String,
        apiBase: String,
        visitorId: String,
        /// Opaque JSON, forwarded verbatim (design 3.4).
        config: Data,
        /// Opaque JSON, or nil for a fresh install.
        prefs: Data?,
        lang: String?
    )
    case view(CompliantView)
    case catalog(lang: String, catalog: Data?)
    case httpResult(id: String, result: HTTPBridgeResult)
    case downloadResult(id: String, result: DownloadBridgeResult)

    /// The wire `type` this case carries. Exists so a serialisation failure
    /// can name WHICH message the page will never receive — "init" and "view"
    /// have very different consequences, and a bare error naming neither
    /// leaves the reader guessing.
    var typeName: String {
        switch self {
        case .init_: return "init"
        case .view: return "view"
        case .catalog: return "catalog"
        case .httpResult: return "httpResult"
        case .downloadResult: return "downloadResult"
        }
    }

    /// Serialises to the JSON string handed to
    /// `window.__compliantHostMessage(...)`.
    func jsonString() throws -> String {
        var object: [String: Any] = ["source": compliantChannel]

        switch self {
        case let .init_(siteKey, apiBase, visitorId, config, prefs, lang):
            object["type"] = "init"
            object["siteKey"] = siteKey
            object["apiBase"] = apiBase
            object["visitorId"] = visitorId
            // Parsed back into a live object, never embedded as a string:
            // the page reads message.config.consentValidityDays directly.
            object["config"] = try Self.jsonValue(from: config)
            // `map`, not `flatMap { try? }`. nil means "no stored decision"
            // and NSNull is right for it; bytes that are present but
            // unparseable mean the store is CORRUPT, and sending NSNull for
            // those tells the page the visitor never answered. It re-prompts,
            // `persist` overwrites, and the decision is gone — with nothing in
            // onError, because the swallow had already called it fine.
            // Throwing hands it to WebViewHost.send, which reports it and
            // delivers nothing (ledger row 398).
            object["prefs"] = try prefs.map { try Self.jsonValue(from: $0) } ?? NSNull()
            object["lang"] = lang ?? NSNull()

        case let .view(view):
            object["type"] = "view"
            object["view"] = view.rawValue

        case let .catalog(lang, catalog):
            object["type"] = "catalog"
            object["lang"] = lang
            // Same swallow as `prefs`, lower stakes and still wrong: nil
            // legitimately means "no file bundled for this locale, keep
            // rendering English", so a corrupt catalog silently became "no
            // translation" and a Hindi visitor read an English notice with
            // nothing logged anywhere (ledger row 398).
            object["catalog"] = try catalog.map { try Self.jsonValue(from: $0) } ?? NSNull()

        case let .httpResult(id, result):
            object["type"] = "httpResult"
            object["id"] = id
            switch result {
            case let .ok(data):
                // A successful response with a non-JSON body is still a
                // success; the page reads `data` and ignores what it cannot use.
                //
                // This `try?` is DELIBERATE and is not row 398 — unlike `prefs`
                // and `catalog` above, nothing is lost by it. Throwing here
                // would turn a request that actually succeeded into no reply at
                // all, leaving the page waiting forever on an id it will never
                // hear about. Asserted by
                // testANonJSONHttpResultBodyStaysASuccess.
                let value = (try? Self.jsonValue(from: data)) ?? NSNull()
                object["result"] = ["ok": true, "data": value]
            case let .failure(kind, status):
                var payload: [String: Any] = ["ok": false, "error": kind]
                if let status { payload["status"] = status }
                object["result"] = payload
            }

        case let .downloadResult(id, result):
            object["type"] = "downloadResult"
            object["id"] = id
            switch result {
            case .ok:
                object["result"] = ["ok": true]
            case let .failure(kind, status):
                var payload: [String: Any] = ["ok": false, "error": kind]
                if let status { payload["status"] = status }
                object["result"] = payload
            }
        }

        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        guard let string = String(data: data, encoding: .utf8) else {
            throw ProtocolError.malformedJSON
        }
        return string
    }

    private static func jsonValue(from data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }
}

// MARK: - Page -> host

/// Messages the page sends. None carries `source` — that absence is how the
/// two families are told apart structurally rather than by naming convention.
enum PageEvent {
    case ready(timeToReadyMs: Double)
    case painted(timeToPaintMs: Double)
    /// Both fields always arrive together, never a partial patch. Opaque JSON.
    case persist(prefs: Data?, lang: String?)
    case decision(prefs: Data, signals: [String: ConsentSignalState])
    case viewChanged(CompliantView)
    case catalogRequest(lang: String)
    case httpRequest(HTTPRequestSpec)
    case download(DownloadSpec)
    case error(message: String)

    /// Outbound page messages always arrive as a JSON string — `postToHost`
    /// stringifies before handing the payload to any transport
    /// (EMBEDDED.md section 5).
    static func decode(_ raw: String) throws -> PageEvent {
        guard
            let object = try? JSONSerialization.jsonObject(with: Data(raw.utf8)),
            let message = object as? [String: Any],
            let type = message["type"] as? String
        else { throw ProtocolError.malformedJSON }

        switch type {
        case "ready":
            return .ready(timeToReadyMs: message["timeToReadyMs"] as? Double ?? 0)

        case "painted":
            return .painted(timeToPaintMs: message["timeToPaintMs"] as? Double ?? 0)

        case "persist":
            return .persist(
                prefs: try reEncode(message["prefs"]),
                lang: message["lang"] as? String
            )

        case "decision":
            guard let prefs = try reEncode(message["prefs"]) else {
                throw ProtocolError.missingField("prefs")
            }
            var signals: [String: ConsentSignalState] = [:]
            for (key, value) in (message["signals"] as? [String: String] ?? [:]) {
                if let state = ConsentSignalState(rawValue: value) { signals[key] = state }
            }
            return .decision(prefs: prefs, signals: signals)

        case "viewChanged":
            guard
                let raw = message["view"] as? String,
                let view = CompliantView(rawValue: raw)
            else { throw ProtocolError.missingField("view") }
            return .viewChanged(view)

        case "catalogRequest":
            guard let lang = message["lang"] as? String else {
                throw ProtocolError.missingField("lang")
            }
            return .catalogRequest(lang: lang)

        case "httpRequest":
            guard
                let id = message["id"] as? String,
                let method = message["method"] as? String,
                let path = message["path"] as? String
            else { throw ProtocolError.missingField("httpRequest") }
            return .httpRequest(
                HTTPRequestSpec(id: id, method: method, path: path,
                                body: try reEncode(message["body"]))
            )

        case "download":
            guard
                let id = message["id"] as? String,
                let method = message["method"] as? String,
                let path = message["path"] as? String,
                let filename = message["filename"] as? String
            else { throw ProtocolError.missingField("download") }
            return .download(
                DownloadSpec(id: id, method: method, path: path,
                             body: try reEncode(message["body"]), filename: filename)
            )

        case "error":
            return .error(message: message["message"] as? String ?? "unknown page error")

        default:
            throw ProtocolError.unknownEventType(type)
        }
    }

    /// Turns a decoded JSON value back into bytes so the shell can store or
    /// forward it without ever modelling its shape. NSNull and absence both
    /// become nil — the page means the same thing by each.
    private static func reEncode(_ value: Any?) throws -> Data? {
        guard let value, !(value is NSNull) else { return nil }
        return try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
    }
}
