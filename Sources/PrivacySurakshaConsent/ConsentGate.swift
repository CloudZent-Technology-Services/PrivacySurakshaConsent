import Foundation

/// JOB 1 — decide whether consent is needed, natively, creating no WebView.
///
/// THIS IS THE NAMED EXCEPTION (design 4.4). It is the only place a shell
/// re-implements web-core logic, and it exists because job 1 and
/// packages/banner/src/embedded.ts:104-111 pull in opposite directions: the
/// page computes expiry and ledger-341 drift AFTER init, but a shell that
/// waits for the page has already paid ~330 ms creating the WebView, which is
/// the entire cost the architecture exists to avoid.
///
/// A shell that skipped this and checked only "does a decision exist?" would
/// never re-prompt on expiry and never re-prompt on a material change. That is
/// a compliance divergence from the web surface, not a cosmetic one.
///
/// The anti-drift mechanism is packages/banner/fixtures/renewal-cases.json,
/// run by both this and packages/banner/src/renewal.test.ts. Any OTHER
/// web-core logic appearing in a shell is a defect, not a precedent.
enum ConsentGate {

    enum Reason: String, Equatable {
        case noDecision
        case expired
        case drifted
    }

    enum Decision: Equatable {
        case notNeeded
        case needed(reason: Reason)
    }

    /// Mirrors `isExpired` in packages/banner/src/renewal.ts.
    ///
    /// `atServer` is accepted for signature symmetry with driftedPurposeIds
    /// but is deliberately unused: renewal.ts's isExpired reads only `at`.
    /// Expiry is a business validity window measured from when the visitor
    /// acted, and switching it to the server clock would change behaviour the
    /// web surface does not have.
    static func isExpired(
        savedAt: String, atServer: String?, validityDays: Int, now: Date
    ) -> Bool {
        // Fails closed: a non-positive window is "always re-prompt", never
        // "never expires".
        guard validityDays > 0 else { return true }
        guard let at = parseISO(savedAt) else { return true }
        let elapsedMs = now.timeIntervalSince(at) * 1000
        return elapsedMs > Double(validityDays) * 86_400_000
    }

    /// Mirrors `findDriftedPurposeIds` in packages/banner/src/renewal.ts.
    ///
    /// Two details are load-bearing and easy to get wrong:
    ///
    /// 1. `atServer` is preferred over `at`. materialSince is a SERVER
    ///    timestamp; comparing it against a device clock that runs fast would
    ///    silently miss a material change published inside the skew window.
    /// 2. The comparison is LEXICOGRAPHIC string comparison, not date parsing.
    ///    Both sides are ISO-8601 UTC with exactly three fractional digits and
    ///    a Z suffix, so string order is time order — and this avoids a
    ///    parse-failure path on every purpose on every launch.
    ///
    /// Strict `<`: a decision recorded at the same instant as the publish
    /// counts as covering it.
    static func driftedPurposeIds(
        savedAt: String, atServer: String?, purposes: [[String: Any]]
    ) -> [String] {
        let decidedAt = atServer ?? savedAt
        return purposes.compactMap { purpose in
            guard
                let id = purpose["id"] as? String,
                let materialSince = purpose["materialSince"] as? String,
                decidedAt < materialSince
            else { return nil }
            return id
        }
    }

    /// The whole of job 1, from the two opaque JSON blobs the shell holds.
    ///
    /// Expiry is evaluated before drift and reported in preference to it,
    /// matching embedded.ts:110 — an expired decision is re-prompted from
    /// scratch, so evaluating drift on top of it is dead work.
    static func decide(prefs: Data?, config: Data, now: Date) -> Decision {
        guard
            let prefs,
            let object = try? JSONSerialization.jsonObject(with: prefs) as? [String: Any],
            let savedAt = object["at"] as? String
        else { return .needed(reason: .noDecision) }

        let atServer = object["atServer"] as? String
        let configObject = (try? JSONSerialization.jsonObject(with: config)) as? [String: Any]

        // Absent consentValidityDays fails closed via isExpired's own guard:
        // 0 is not > 0, so it returns true.
        let validityDays = configObject?["consentValidityDays"] as? Int ?? 0
        if isExpired(savedAt: savedAt, atServer: atServer,
                     validityDays: validityDays, now: now) {
            return .needed(reason: .expired)
        }

        let purposes = configObject?["purposes"] as? [[String: Any]] ?? []
        if !driftedPurposeIds(savedAt: savedAt, atServer: atServer,
                              purposes: purposes).isEmpty {
            return .needed(reason: .drifted)
        }

        return .notNeeded
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// SavedPrefs.at is always `new Date().toISOString()`, which always has
    /// three fractional digits. The fallback handles a hand-written or legacy
    /// value that lacks them rather than treating it as unparseable.
    private static func parseISO(_ value: String) -> Date? {
        if let date = isoFormatter.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}
