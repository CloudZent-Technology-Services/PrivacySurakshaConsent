import XCTest
@testable import PrivacySurakshaConsent

/// Answers the page's `catalogRequest` from bundled assets with no network
/// (conformance item 9). `catalog: null` is a legitimate answer meaning "no
/// bundled file for that locale" — the page then keeps rendering English,
/// matching the web build's behaviour on a 404.
final class CatalogReaderTests: XCTestCase {

    // Uses the default `bundle: Bundle = .module` parameter rather than
    // passing `.module` explicitly here. A `.module` literal written in this
    // file resolves against *this* target's own generated accessor
    // (CompliantConsentTests' resource bundle, which only has
    // renewal-cases.json) because default-argument expressions are type-
    // checked in the scope where they're declared, not the call site — see
    // ResourcesTests.swift's `libraryResourceBundle()` doc comment for the
    // same pitfall from the other direction.
    private let subject = CatalogReader()

    func testReadsABundledNonEnglishCatalog() throws {
        let data = try XCTUnwrap(subject.catalog(for: "hi"), "hi is in the manifest")
        let object = try JSONSerialization.jsonObject(with: data)
        XCTAssertTrue(object is [String: Any], "a catalog is a JSON object")
    }

    func testReadsARightToLeftCatalog() throws {
        XCTAssertNotNil(subject.catalog(for: "ur"), "Urdu is one of the 23 and renders RTL")
    }

    /// nil, not a throw and not an empty object: the page treats nil as
    /// "fall back to English", and an empty object would render blank strings.
    func testReturnsNilForALocaleWithNoBundledFile() {
        XCTAssertNil(subject.catalog(for: "zz"))
    }

    /// Locale identifiers come from the page, which reads them from config.
    /// A path separator here would otherwise escape the bundle directory.
    func testRejectsAPathTraversalAttempt() {
        XCTAssertNil(subject.catalog(for: "../manifest"))
        XCTAssertNil(subject.catalog(for: "a/b"))
    }

    /// Read from the manifest, never hardcoded — the list grows as
    /// packages/i18n/catalogs/ grows (EMBEDDED.md section 2).
    func testAvailableLocalesComesFromTheManifest() throws {
        let locales = subject.availableLocales
        XCTAssertTrue(locales.contains("en"))
        XCTAssertTrue(locales.contains("ur"))
        XCTAssertGreaterThanOrEqual(locales.count, 23)
    }

    func testEveryAdvertisedLocaleIsActuallyReadable() throws {
        for lang in subject.availableLocales {
            XCTAssertNotNil(subject.catalog(for: lang), "\(lang) is advertised but unreadable")
        }
    }
}
