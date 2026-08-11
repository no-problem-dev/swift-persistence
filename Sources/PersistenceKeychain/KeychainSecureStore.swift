// The Keychain is an Apple-platform service with no counterpart on Linux, so this whole file
// compiles away there and `PersistenceKeychain` becomes an empty module rather than a build
// failure. ``SecureStore`` itself lives in `PersistenceCore` and stays available everywhere, so a
// Linux caller conforms their own type to it — libsecret, a KMS, an encrypted file — and injects
// that wherever this store would have gone.
#if canImport(Security)

import Foundation
import Security
import PersistenceCore

/// How soon after a restart an item can be read, and whether it survives onto another device.
///
/// These map onto the `kSecAttrAccessible` attribute. The `thisDeviceOnly` variants are left out
/// of encrypted backups, so the credential is absent after a restore onto new hardware and the
/// app has to obtain it again; the other two travel in the backup.
///
/// None of them makes an item sync through iCloud Keychain. That needs the separate
/// `kSecAttrSynchronizable` attribute, which this store never sets, so no item written here ever
/// leaves the device except through a backup.
public enum KeychainAccessibility: Sendable {
    /// Readable only while the device is unlocked, and left behind by a restore onto new hardware.
    ///
    /// The default, and the right choice for auth tokens and API keys: unreadable while the
    /// screen is locked, and never present in a backup.
    case whenUnlockedThisDeviceOnly

    /// Readable only while the device is unlocked, and carried into encrypted backups.
    ///
    /// Choose this when the credential should survive the user replacing their device.
    case whenUnlocked

    /// Readable from the first unlock after a restart onwards, and left behind by a restore.
    ///
    /// What background work needs, since it may run while the screen is locked. The cost is that
    /// the value stays readable for the rest of the boot, locked screen or not.
    case afterFirstUnlockThisDeviceOnly

    /// Readable from the first unlock after a restart onwards, and carried into encrypted backups.
    ///
    /// The most permissive of the four.
    case afterFirstUnlock

    var rawValue: CFString {
        switch self {
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .whenUnlocked:
            return kSecAttrAccessibleWhenUnlocked
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .afterFirstUnlock:
            return kSecAttrAccessibleAfterFirstUnlock
        }
    }
}

/// Stores secrets in the system Keychain, one generic-password item per key.
///
/// A key becomes the account attribute of its own item under a shared service name, so two
/// stores built with different service names never see each other's items, and deleting one key
/// leaves the rest alone. Nothing is cached: every call is an IPC round trip to the Keychain.
///
/// Items are readable only under the accessibility class given at initialisation, by default
/// while the device is unlocked and only on this device. With an access group, every target
/// carrying that same group entitlement reads the same items, which is how an app shares a
/// credential with its extensions; without one, the items belong to this app alone.
///
/// Being an actor, calls are serialised and run off the caller's actor. The Keychain calls are
/// synchronous and hold the store's executor while the daemon answers. A read attempted while
/// the item is not accessible fails immediately rather than waiting for the device to unlock.
public actor KeychainSecureStore: SecureStore {

    private let service: String
    private let accessGroup: String?
    private let accessibility: KeychainAccessibility

    /// Creates a store over one Keychain service, without reaching the Keychain yet.
    ///
    /// Nothing is read or written here, so an initialiser that returns says nothing about whether
    /// the Keychain is usable. A missing entitlement surfaces on the first read or write.
    ///
    /// - Parameters:
    ///   - service: Namespace for this store's items. Defaults to the bundle identifier, falling
    ///     back to a fixed string when there is none, which is the case in command-line tools and
    ///     some test runners; two such processes would then share one namespace.
    ///   - accessGroup: Shares the items with every target carrying the same keychain access
    ///     group entitlement. `nil` keeps them private to this app.
    ///   - accessibility: When items may be read, and whether they survive a restore onto new
    ///     hardware. This applies to items written from now on; items already in the Keychain keep
    ///     the class they were written with until they are written again.
    public init(
        service: String = Bundle.main.bundleIdentifier ?? "com.app.persistence",
        accessGroup: String? = nil,
        accessibility: KeychainAccessibility = .whenUnlockedThisDeviceOnly
    ) {
        self.service = service
        self.accessGroup = accessGroup
        self.accessibility = accessibility
    }

    // MARK: - SecureStore

    public func getString(forKey key: String) throws -> String? {
        guard let data = try getData(forKey: key) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.decodingFailed(
                key: key,
                reason: "Stored data is not valid UTF-8"
            )
        }
        return string
    }

    public func setString(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw PersistenceError.encodingFailed(
                key: key,
                reason: "String to UTF-8 conversion failed"
            )
        }
        try setData(data, forKey: key)
    }

    /// Reads the bytes held under a key.
    ///
    /// - Returns: `nil` when no item exists under the key.
    /// - Throws: ``PersistenceError/accessDenied(reason:)`` for every other failure, carrying the
    ///   raw `OSStatus`. Despite the name that covers more than permissions: a read while the
    ///   device is locked and a query the Keychain rejected arrive the same way, so read the
    ///   status before concluding an entitlement is missing.
    public func getData(forKey key: String) throws -> Data? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw PersistenceError.accessDenied(
                reason: "Keychain read failed: OSStatus \(status)"
            )
        }
    }

    /// Writes bytes under a key, replacing any existing item and resetting its accessibility.
    ///
    /// An item written before the store was created with a different accessibility class is
    /// brought onto the current one by this call.
    public func setData(_ value: Data, forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let attributes: [String: Any] = [
            kSecValueData as String: value,
            kSecAttrAccessible as String: accessibility.rawValue,
        ]

        // Update first: adding on top of an existing item fails with errSecDuplicateItem.
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // First write for this key, so there is nothing to update.
            var addQuery = query
            addQuery[kSecValueData as String] = value
            addQuery[kSecAttrAccessible as String] = accessibility.rawValue
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw PersistenceError.storageFailed(
                operation: "setData",
                reason: "Keychain write failed: OSStatus \(status)"
            )
        }
    }

    public func remove(forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PersistenceError.storageFailed(
                operation: "remove",
                reason: "Keychain delete failed: OSStatus \(status)"
            )
        }
    }

    public func contains(key: String) throws -> Bool {
        try getData(forKey: key) != nil
    }

    // MARK: - Private

    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }
        return query
    }
}

#endif
