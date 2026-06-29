import Foundation
import PersistenceCore

/// テスト用のインメモリ ``SecureStore``。
///
/// アクター分離によりロック同期を置き換え、
/// エンタイトルメントや実 Keychain なしで Keychain の挙動をシミュレートする。
public actor InMemorySecureStore: SecureStore {

    private var storage: [String: Data] = [:]

    public init() {}

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
        storage[key]
    }

    public func setData(_ value: Data, forKey key: String) throws {
        storage[key] = value
    }

    public func remove(forKey key: String) {
        storage.removeValue(forKey: key)
    }

    public func contains(key: String) throws -> Bool {
        storage[key] != nil
    }

    /// 格納エントリ数（テストアサーション用）。
    public var count: Int {
        storage.count
    }
}
