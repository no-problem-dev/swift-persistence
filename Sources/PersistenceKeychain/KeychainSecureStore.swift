import Foundation
import Security
import PersistenceCore

/// Keychain アイテムのアクセシビリティポリシー。
///
/// `kSecAttrAccessible` 属性にマッピングされる。`thisDeviceOnly` バリアントは
/// iCloud Keychain 同期を抑制し、クレデンシャルのデバイス外への漏洩を防ぐ。
public enum KeychainAccessibility: Sendable {
    /// デバイスのロック解除中のみアクセス可能。iCloud Keychain に同期しない。
    ///
    /// 認証トークン・機密クレデンシャルの推奨デフォルト
    /// （Apple Review §2.1 データ保護要件に準拠）。
    case whenUnlockedThisDeviceOnly

    /// デバイスのロック解除中のみアクセス可能。iCloud Keychain に同期する。
    ///
    /// 複数デバイス間でクレデンシャルを共有する必要がある場合に使用。
    case whenUnlocked

    /// 再起動後の初回ロック解除以降アクセス可能。iCloud Keychain に同期しない。
    ///
    /// バックグラウンドタスクが必要とするクレデンシャルに使用。
    case afterFirstUnlockThisDeviceOnly

    /// 再起動後の初回ロック解除以降アクセス可能。iCloud Keychain に同期する。
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

/// システム Keychain をバックエンドとする ``SecureStore`` 実装。
///
/// `kSecClassGenericPassword` と設定可能なサービス名を使用する。
/// 各キーはアカウント属性にキーを設定した独立した Keychain アイテムとして格納される。
///
/// アクターとして実装することで、Keychain IPC を呼び出し元アクターから切り離し、
/// データレース安全性を確保する。
public actor KeychainSecureStore: SecureStore {

    private let service: String
    private let accessGroup: String?
    private let accessibility: KeychainAccessibility

    /// Keychain バックドセキュアストアを生成する。
    ///
    /// - Parameters:
    ///   - service: Keychain サービス識別子。デフォルトはアプリのバンドル識別子。
    ///   - accessGroup: アプリ・エクステンション間の Keychain 共有に使うアクセスグループ（省略可）。
    ///   - accessibility: Keychain アイテムのアクセシビリティポリシー。デフォルトは
    ///     ``KeychainAccessibility/whenUnlockedThisDeviceOnly`` — デバイスのロック解除中のみ
    ///     読み取り可能で iCloud Keychain に同期しない。認証トークン・API キーの推奨デフォルト
    ///     （Apple Review §2.1 データ保護に準拠）。
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

        // まず更新を試みる
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            // アイテムが存在しない場合は追加する
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
