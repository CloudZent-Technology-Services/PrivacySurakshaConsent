import Foundation

/// Everything a customer configures. Four lines in
/// application(_:didFinishLaunchingWithOptions:).
public struct CompliantConfiguration {

    /// The customer's public site key, from the dashboard.
    public let siteKey: String

    /// Origin only, no trailing slash — e.g. https://api.privacysuraksha.com
    public let apiBase: URL

    /// Row 384's app key, issued per app at dashboard -> site -> Mobile apps.
    ///
    /// This is CONFIGURATION, NOT A SECRET. It ships inside the app binary and
    /// can be extracted from it, so an app-sourced consent record is
    /// attributable to a registered app SURFACE, not to a verified genuine
    /// INSTALL. Device attestation is ledger row 384, deliberately deferred.
    /// State the weaker claim in customer-facing material, never the stronger.
    ///
    /// nil sends no header, which is correct against a site that has
    /// registered no apps — that is how an integration is tested before it
    /// has one.
    public var appKey: String?

    /// Receives the decision so it can reach Google Consent Mode v2. The SDK
    /// ships no Firebase dependency; see mobile/ios/README.md for the adapter.
    public var signalWriter: ConsentSignalWriter?

    public init(
        siteKey: String,
        apiBase: URL,
        appKey: String? = nil,
        signalWriter: ConsentSignalWriter? = nil
    ) {
        self.siteKey = siteKey
        self.apiBase = apiBase
        self.appKey = appKey
        self.signalWriter = signalWriter
    }
}
