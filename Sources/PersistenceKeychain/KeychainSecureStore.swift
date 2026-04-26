import Foundation
import Security
import PersistenceCore

/// Keychain item の accessibility ポリシー。
///
/// `kSecAttrAccessible` 属性に対応する。`thisDeviceOnly` 系列は iCloud Keychain
/// への同期を抑止し、デバイス外への credential 漏洩を防ぐ。
public enum KeychainAccessibility: Sendable {
    /// デバイスがアンロック中のみアクセス可能。iCloud 同期しない。
    ///
    /// 認証トークンや機密 credential のデフォルト推奨値 (Apple Review §2.1 整合)。
    case whenUnlockedThisDeviceOnly

    /// デバイスがアンロック中のみアクセス可能。iCloud 同期する。
    ///
    /// 複数デバイス間で共有したい credential 用。
    case whenUnlocked

    /// 起動後初回アンロック以降アクセス可能。iCloud 同期しない。
    ///
    /// バックグラウンド処理で必要な credential 用。
    case afterFirstUnlockThisDeviceOnly

    /// 起動後初回アンロック以降アクセス可能。iCloud 同期する。
    case afterFirstUnlock

    fileprivate var rawValue: CFString {
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

/// ``SecureStore`` backed by the system Keychain.
///
/// Uses `kSecClassGenericPassword` with a configurable service name.
/// Each key is stored as a separate Keychain item with the key as the account attribute.
///
/// Implemented as an `actor` to move Keychain IPC off the caller's actor
/// and to provide data-race safety.
public actor KeychainSecureStore: SecureStore {

    private let service: String
    private let accessGroup: String?
    private let accessibility: KeychainAccessibility

    /// Creates a Keychain-backed secure store.
    ///
    /// - Parameters:
    ///   - service: Keychain service identifier. Defaults to the app's bundle identifier.
    ///   - accessGroup: Optional Keychain access group for sharing across apps/extensions.
    ///   - accessibility: Keychain item accessibility policy. Defaults to
    ///     ``KeychainAccessibility/whenUnlockedThisDeviceOnly`` — credentials are
    ///     readable only while the device is unlocked and never sync to iCloud
    ///     Keychain. This is the recommended default for auth tokens / API keys
    ///     to satisfy Apple Review §2.1 (data protection).
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

    public func setData(_ value: Data, forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let attributes: [String: Any] = [
            kSecValueData as String: value,
            kSecAttrAccessible as String: accessibility.rawValue,
        ]

        // Try update first
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // Item does not exist — add it
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
