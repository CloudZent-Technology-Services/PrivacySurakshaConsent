import Foundation
import Security

/// JOB 3 — persist a device identifier we generate ourselves.
///
/// NEVER IDFA, NEVER AAID, and never identifierForVendor. Using an
/// advertising identifier would make the consent record itself a tracking
/// identifier (parent design 4.4), and identifierForVendor is unstable in ways
/// that would silently re-prompt.
struct DeviceIdentifier {

    enum KeychainError: Error {
        case unhandled(OSStatus)
    }

    private let service: String
    private let account = "visitor-id"

    init(service: String = "com.compliant.consent") {
        self.service = service
    }

    /// Returns the stored identifier, generating and storing one on first use.
    ///
    /// A Keychain failure is not fatal: it returns a fresh session-scoped UUID
    /// alongside the error, so the notice still works and the customer can log
    /// the problem. It NEVER falls back to a device-derived value — a
    /// fabricated stable identifier is worse than an unstable one, because the
    /// consent record exists to be evidence.
    func current() -> (id: String, error: Error?) {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess,
           let data = item as? Data,
           let stored = String(data: data, encoding: .utf8),
           UUID(uuidString: stored) != nil {
            return (stored, nil)
        }

        let generated = UUID().uuidString.lowercased()
        if let error = store(generated) {
            return (generated, error)
        }
        // A successful store means the recovery worked, whatever the original
        // read status was (missing entry on first use, or a corrupted one
        // that failed the UUID check above) — report no error either way.
        // Surfacing the original read status here would report a spurious
        // error on a corrupted-entry recovery even though the fresh id was
        // generated and persisted correctly.
        return (generated, nil)
    }

    /// Removes the stored identifier. Used by tests to isolate runs; `internal`
    /// like the rest of this type — nothing in this file is part of the SDK's
    /// public surface (see plan Global Constraints).
    func reset() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func store(_ id: String) -> Error? {
        SecItemDelete(baseQuery() as CFDictionary)

        var attributes = baseQuery()
        attributes[kSecValueData as String] = Data(id.utf8)
        // Available after first unlock and never synced to another device: a
        // consent record is device-scoped evidence, and iCloud Keychain
        // syncing would silently share one visitor id across devices.
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess ? nil : KeychainError.unhandled(status)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
