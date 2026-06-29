import Foundation
import PersistenceCore

/// `UserDefaults` をバックエンドとする ``KeyValueStore`` 実装。
///
/// プリミティブ型（`String`, `Bool`, `Int`, `Double`, `Data`）は
/// UserDefaults のネイティブアクセサを効率的に使用する。
/// それ以外の `Codable` 型は `JSONEncoder`/`JSONDecoder` で変換する。
///
/// アクターとして実装することでエンコーダー・デコーダーへのアクセスが
/// データレース安全となり、呼び出し元アクターから作業を切り離す。
public actor UserDefaultsKeyValueStore: KeyValueStore {

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// UserDefaults バックドキーバリューストアを生成する。
    ///
    /// - Parameter suiteName: 共有 `UserDefaults` コンテナのスイート名（省略可）。
    ///   `nil` の場合は `.standard` を使用。
    public init(suiteName: String? = nil) {
        self.defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func value<T: Codable & Sendable>(forKey key: String, type: T.Type) throws -> T? {
        // プリミティブ型のファストパス
        if type == String.self {
            return defaults.string(forKey: key) as? T
        }
        if type == Bool.self {
            guard defaults.object(forKey: key) != nil else { return nil }
            return defaults.bool(forKey: key) as? T
        }
        if type == Int.self {
            guard defaults.object(forKey: key) != nil else { return nil }
            return defaults.integer(forKey: key) as? T
        }
        if type == Double.self {
            guard defaults.object(forKey: key) != nil else { return nil }
            return defaults.double(forKey: key) as? T
        }
        if type == Data.self {
            return defaults.data(forKey: key) as? T
        }

        // Codable パス
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PersistenceError.decodingFailed(key: key, reason: error.localizedDescription)
        }
    }

    public func setValue<T: Codable & Sendable>(_ value: T, forKey key: String) throws {
        // プリミティブ型のファストパス
        if let s = value as? String { defaults.set(s, forKey: key); return }
        if let b = value as? Bool { defaults.set(b, forKey: key); return }
        if let i = value as? Int { defaults.set(i, forKey: key); return }
        if let d = value as? Double { defaults.set(d, forKey: key); return }
        if let data = value as? Data { defaults.set(data, forKey: key); return }

        // Codable パス
        do {
            let data = try encoder.encode(value)
            defaults.set(data, forKey: key)
        } catch {
            throw PersistenceError.encodingFailed(key: key, reason: error.localizedDescription)
        }
    }

    public func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
    }

    public func contains(key: String) -> Bool {
        defaults.object(forKey: key) != nil
    }
}
