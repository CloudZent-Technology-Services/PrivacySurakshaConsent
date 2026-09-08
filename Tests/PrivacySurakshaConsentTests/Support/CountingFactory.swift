import WebKit
@testable import PrivacySurakshaConsent

/// Counts how many WebViews were created. This is the seam conformance item 2
/// asserts against: "a second launch creates NO WebView" is the entire latency
/// argument, and it has to be assertable rather than assumed.
@MainActor
final class CountingFactory: WebViewFactory {
    private(set) var creations = 0

    func makeWebView(configuration: WKWebViewConfiguration) -> WKWebView {
        creations += 1
        return WKWebView(frame: .zero, configuration: configuration)
    }
}
