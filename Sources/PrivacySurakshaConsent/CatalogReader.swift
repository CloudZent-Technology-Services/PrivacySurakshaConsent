import Foundation

/// Answers `catalogRequest` from the committed bundle. No network is involved
/// at any point — that is conformance item 9, and it is why the catalogs are
/// shipped as assets rather than fetched.
struct CatalogReader {

    private let bundle: Bundle

    init(bundle: Bundle = .module) {
        self.bundle = bundle
    }

    /// The locale list from manifest.json. NEVER a hardcoded 23 — the list
    /// grows with packages/i18n/catalogs/, and a shell that hardcodes the
    /// count goes silently stale (EMBEDDED.md section 2).
    var availableLocales: [String] {
        guard
            let url = bundle.url(forResource: "Resources/manifest.json", withExtension: nil),
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let locales = object["locales"] as? [String]
        else { return [] }
        return locales
    }

    /// The catalog for a locale, or nil if none is bundled.
    ///
    /// nil is a legitimate answer, not an error: `catalog: null` tells the page
    /// to keep rendering English, matching the web build's behaviour on a 404.
    func catalog(for lang: String) -> Data? {
        // The locale string comes from the page, which took it from config.
        // Restricting it to the shape a BCP-47 subtag can take keeps a
        // separator or a traversal segment from escaping the bundle directory.
        guard isSafeLocale(lang) else { return nil }
        guard
            let url = bundle.url(forResource: "Resources/i18n/\(lang).json", withExtension: nil)
        else { return nil }
        return try? Data(contentsOf: url)
    }

    private func isSafeLocale(_ lang: String) -> Bool {
        !lang.isEmpty
            && lang.count <= 12
            && lang.allSatisfy { $0.isASCII && ($0.isLetter || $0 == "-") }
    }
}
