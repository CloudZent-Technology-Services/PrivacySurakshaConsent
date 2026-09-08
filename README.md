# PrivacySurakshaConsent — iOS

The DPDP consent notice for an iOS app. It is the same notice a website
visitor sees, because it is the same underlying banner code, compiled and
bundled into this package and shown in a `WKWebView`.

## Requirements

- iOS 15.0+
- Swift 5.9+
- No third-party dependencies.

## Install

In Xcode: **File → Add Package Dependencies**, then the repository URL and a
version tag.

Or in your `Package.swift`:

```swift
dependencies: [
    // TODO: replace <org>/<repo> with this package's actual GitHub location.
    .package(url: "https://github.com/<org>/<repo>", from: "0.1.0"),
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "PrivacySurakshaConsent", package: "<repo>"),
    ]),
]
```

## Use

```swift
import PrivacySurakshaConsent

func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    CompliantConsent.start(.init(
        siteKey: "sk_your_site_key",
        apiBase: URL(string: "https://api.privacysuraksha.com")!,
        appKey:  "app_your_app_key"
    ))
    return true
}
```

Call it as early as you can. It returns immediately and works in the
background — calling it later only delays the notice.

A "Privacy settings" entry point anywhere in your app:

```swift
Button("Privacy settings") {
    CompliantConsent.show(.prefs)
}
```

Failures worth logging:

```swift
CompliantConsent.onError = { error in
    print("consent: \(error)")
}
```

## Where the keys come from

- **`siteKey`** — dashboard → your site. It is public; it is already in your
  website's page source.
- **`appKey`** — dashboard → your site → **Mobile apps** → register this app
  by its bundle identifier. You are shown the key once.

If your site has registered no apps, leave `appKey` as `nil` and everything
works. The moment you register one, consent requests from apps must carry a
valid key — **including from a build you shipped before registering**, so
register before you release.

## Google Consent Mode v2

The SDK does not depend on Firebase. If it did, every app using this SDK
would pull in Firebase whether it wanted it or not. You write the adapter,
which is about five lines:

```swift
import FirebaseAnalytics
import PrivacySurakshaConsent

final class FirebaseConsentWriter: ConsentSignalWriter {
    func write(_ signals: [String: ConsentSignalState]) {
        Analytics.setConsent(signals.reduce(into: [:]) { result, pair in
            guard let type = Self.types[pair.key] else { return }
            result[type] = pair.value == .granted ? ConsentStatus.granted : .denied
        })
    }

    private static let types: [String: ConsentType] = [
        "ad_storage": .adStorage,
        "analytics_storage": .analyticsStorage,
        "ad_user_data": .adUserData,
        "ad_personalization": .adPersonalization,
    ]
}
```

Then pass it in:

```swift
CompliantConsent.start(.init(
    siteKey: "sk_...", apiBase: apiBase, appKey: "app_...",
    signalWriter: FirebaseConsentWriter()
))
```

If your writer throws, the SDK reports it through `onError` and carries on.
The consent record is already saved by then — losing an analytics signal must
never cost the record.

## Things you should know

**The app key is inside your binary and can be extracted from it.** That is by design, and it is worth being precise about what it proves: a consent record from your app is attributable to a **registered app**, not to a **verified genuine install** of it. Device attestation (App Attest, Play Integrity) is tracked separately and is not built. Say the weaker thing in anything customer-facing.

**Reinstalling the app shows the notice again.** The device identifier is a
UUID we generate and keep in the Keychain — never IDFA, never the advertising
identifier. A reinstall produces a new one and the visitor is asked again.
That is correct behaviour, not a bug.

**Changing your notice does not need an app release.** The text comes from
your dashboard config, fetched at launch and cached to disk. Edit it in the
dashboard and running apps pick it up.

**With no network and no cached config, no notice is shown and nothing is
recorded.** An app that cannot show a notice must not process anything
non-essential, which is the same state as "no consent". `onError` fires so you can log it.

**Receipt and consent-history downloads do not work inside the app.** They are
built for a browser and are tracked separately.

## Development

```bash
xcodebuild test -scheme PrivacySurakshaConsent \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

`swift build` does not work and is not meant to: the package is iOS-only and
imports UIKit and WebKit.

Everything under `Sources/PrivacySurakshaConsent/Resources/` is generated
upstream (from the web banner's source) and synced into this repo as part of
release. Do not edit it by hand here.

## License

Proprietary. All rights reserved. See [LICENSE](LICENSE) — use of this
software requires prior written permission from CloudZent Technology
Services LLP (www.cloudzent.com).
