import Foundation

/// The durable copy of the visitor's decision and language.
///
/// `UserDefaults`, not the Keychain: this is not a secret, it is state the
/// visitor can legitimately clear by deleting the app, and Keychain survival
/// across reinstall would resurrect a decision the visitor believed they had
/// removed.
///
/// Both fields are written together on every `persist` — the page never sends
/// a partial patch, and treating a nil as "leave unchanged" would strand a
/// cleared value (EMBEDDED.md section 4).
struct PrefsStore {

    private let defaults: UserDefaults
    private let prefsKey = "com.compliant.consent.prefs"
    private let langKey = "com.compliant.consent.lang"

    init(suiteName: String? = nil) {
        if let suiteName, let suite = UserDefaults(suiteName: suiteName) {
            defaults = suite
        } else {
            defaults = .standard
        }
    }

    /// The stored decision as opaque JSON, or nil on a fresh install.
    var prefs: Data? {
        defaults.data(forKey: prefsKey)
    }

    var lang: String? {
        defaults.string(forKey: langKey)
    }

    /// Persists both fields. A nil CLEARS rather than preserves.
    func write(prefs: Data?, lang: String?) {
        if let prefs {
            defaults.set(prefs, forKey: prefsKey)
        } else {
            defaults.removeObject(forKey: prefsKey)
        }
        if let lang {
            defaults.set(lang, forKey: langKey)
        } else {
            defaults.removeObject(forKey: langKey)
        }
    }

    func clear() {
        defaults.removeObject(forKey: prefsKey)
        defaults.removeObject(forKey: langKey)
    }
}
