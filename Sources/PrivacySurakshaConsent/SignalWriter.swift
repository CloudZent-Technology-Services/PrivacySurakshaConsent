import Foundation

/// The Consent Mode v2 keys `consentSignals()` in
/// packages/banner/src/consent-mode.ts can emit. Copied from that file;
/// keep them in sync by hand if it ever gains an eighth.
///
/// Internal, not public: the spec's "one type, three members, plus
/// sdkVersion" line (amended 2026-09-01) does not sanction this as a fourth
/// addition, and it has no consumer outside the module — `normalise` below
/// is itself internal, and the README's own `FirebaseConsentWriter` example
/// writes the seven strings as literals rather than referencing this type.
enum ConsentModeKey {
    static let adStorage = "ad_storage"
    static let analyticsStorage = "analytics_storage"
    static let adUserData = "ad_user_data"
    static let adPersonalization = "ad_personalization"
    static let securityStorage = "security_storage"
    static let functionalityStorage = "functionality_storage"
    static let personalizationStorage = "personalization_storage"

    static let all: [String] = [
        adStorage, analyticsStorage, adUserData, adPersonalization,
        securityStorage, functionalityStorage, personalizationStorage,
    ]
}

/// JOB 4 — the seam through which a decision reaches Google Consent Mode v2.
///
/// This SDK deliberately declares NO Firebase dependency (design 4.3):
/// putting FirebaseAnalytics in Package.swift would make every customer
/// resolve Firebase's dependency graph whether they use it or not, and SPM
/// resolves a package's declared dependencies regardless of which targets a
/// consumer actually uses — so a separate opt-in product would not avoid it.
///
/// The customer implements this in about five lines. See mobile/ios/README.md
/// for the exact snippet.
public protocol ConsentSignalWriter: AnyObject {
    func write(_ signals: [String: ConsentSignalState]) throws
}

/// Prepares the page's `signals` object for a customer's writer.
///
/// This does NOT compute signals from categories — the page has already done
/// that (`consentSignals` in consent-mode.ts), and EMBEDDED.md section 3 job 4
/// forbids re-deriving it precisely so four shells do not drift apart. All
/// this does is make the dictionary total and drop anything unrecognised.
enum ConsentModeMapping {

    /// Returns exactly the seven known keys. Anything the page did not send
    /// defaults to `.denied`, and anything not in ConsentModeKey.all is
    /// dropped — a customer's adapter maps keys onto a fixed Firebase enum,
    /// so an unexpected key is a crash or a silent no-op on their side.
    static func normalise(
        _ signals: [String: ConsentSignalState]
    ) -> [String: ConsentSignalState] {
        var result: [String: ConsentSignalState] = [:]
        for key in ConsentModeKey.all {
            result[key] = signals[key] ?? .denied
        }
        return result
    }
}
