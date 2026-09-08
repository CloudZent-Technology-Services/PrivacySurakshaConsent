// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PrivacySurakshaConsent",
    // iOS only, deliberately. The package imports UIKit and WebKit, so a
    // macOS host build fails by construction — `swift build` is not a
    // supported command here; see the plan's Global Constraints.
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "PrivacySurakshaConsent", targets: ["PrivacySurakshaConsent"]),
    ],
    // Zero dependencies, permanently. See design 4.3: declaring
    // FirebaseAnalytics here would make every customer resolve Firebase's
    // dependency graph whether they use it or not.
    dependencies: [],
    targets: [
        .target(
            name: "PrivacySurakshaConsent",
            // .copy, not .process: the i18n/ subdirectory structure must
            // survive byte-exact, because CatalogReader resolves
            // i18n/<lang>.json by path.
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "PrivacySurakshaConsentTests",
            dependencies: ["PrivacySurakshaConsent"],
            resources: [.copy("Resources")]
        ),
    ]
)
