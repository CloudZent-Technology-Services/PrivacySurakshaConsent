import XCTest
import Security
@testable import PrivacySurakshaConsent

/// JOB 3 — a UUID we generate, stored in the Keychain. Never IDFA, never
/// AAID, never identifierForVendor (design 4.4 of the parent spec). The page's
/// isHostMessage rejects a non-UUID visitorId, so getting this wrong produces
/// an `error` message rather than a working notice.
final class DeviceIdentifierTests: XCTestCase {

    private var subject: DeviceIdentifier!

    override func setUp() {
        super.setUp()
        // A per-test service name keeps runs isolated; the simulator Keychain
        // persists across test invocations otherwise.
        subject = DeviceIdentifier(service: "com.compliant.tests.\(UUID().uuidString)")
        subject.reset()
    }

    override func tearDown() {
        subject.reset()
        subject = nil
        super.tearDown()
    }

    /// In an unsigned test process (`CODE_SIGNING_ALLOWED=NO`, required on
    /// GitHub's macos-latest runner — see .github/workflows/mobile-ios.yml)
    /// the Keychain has no entitlement to grant, so every write fails with
    /// errSecMissingEntitlement (-34018). `current()` reporting that as an
    /// error is correct behaviour (see its own doc comment), not a bug —
    /// it's the same "known DeviceIdentifierTests failures" already called
    /// out in CompliantConsentTests.swift. Skip rather than assert past it:
    /// a properly signed run still exercises the real Keychain path.
    private func skipIfSandboxHasNoKeychainEntitlement(_ error: Error?) throws {
        if let keychainError = error as? DeviceIdentifier.KeychainError,
           case .unhandled(errSecMissingEntitlement) = keychainError {
            throw XCTSkip("Keychain unavailable in this unsigned test process (errSecMissingEntitlement)")
        }
    }

    func testGeneratesAUUIDOnFirstRead() throws {
        let (id, error) = subject.current()
        try skipIfSandboxHasNoKeychainEntitlement(error)
        XCTAssertNil(error)
        XCTAssertNotNil(UUID(uuidString: id), "\(id) is not a UUID and the page would reject it")
    }

    func testIsStableAcrossReads() throws {
        let (first, error) = subject.current()
        try skipIfSandboxHasNoKeychainEntitlement(error)
        let second = subject.current().id
        XCTAssertEqual(first, second)
    }

    /// A fresh service name is the test-visible equivalent of a reinstall.
    /// A new identifier and a re-shown notice is CORRECT behaviour, and the
    /// README must say so plainly (EMBEDDED.md section 3, job 3).
    func testAReinstallProducesANewIdentifier() {
        let before = subject.current().id
        let reinstalled = DeviceIdentifier(service: "com.compliant.tests.\(UUID().uuidString)")
        defer { reinstalled.reset() }
        XCTAssertNotEqual(before, reinstalled.current().id)
    }

    func testLowercasedUUIDFormatMatchesThePageRegex() {
        // protocol.ts's UUID_RE is case-insensitive, but emitting a
        // consistent case avoids a needless difference between shells.
        let id = subject.current().id
        XCTAssertEqual(id, id.lowercased())
    }

    /// Task 4 review: a stored-but-corrupted entry (fails the UUID check in
    /// `current()`) triggers a silent, successful regenerate-and-restore. That
    /// recovery must be reported as success, not as a spurious Keychain error
    /// left over from the original read status.
    func testACorruptedStoredEntryIsSilentlyRecoveredWithNoError() throws {
        let service = "com.compliant.tests.\(UUID().uuidString)"
        let corrupted = DeviceIdentifier(service: service)
        defer { corrupted.reset() }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "visitor-id",
            kSecValueData as String: Data("not-a-uuid".utf8),
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecMissingEntitlement {
            throw XCTSkip("Keychain unavailable in this unsigned test process (errSecMissingEntitlement)")
        }
        XCTAssertEqual(status, errSecSuccess, "test setup must actually plant a corrupted entry")

        let (id, error) = corrupted.current()
        XCTAssertNil(error, "a successful recovery must not report the original read's status as an error")
        XCTAssertNotNil(UUID(uuidString: id), "the recovered value must be a fresh, valid UUID")
    }
}
