import Foundation

/// 型安全なキーバリューストレージ抽象。
///
/// `UserDefaults` など KV ストアをプロトコルでラップし、
/// DI による差し替えとテスト容易性を実現する。
///
/// 実装はファイル I/O を呼び出し元アクターから切り離せるよう `async` メソッドを採用する。
///
/// 実装: ``UserDefaultsKeyValueStore``, ``InMemoryKeyValueStore``。
public protocol KeyValueStore: Sendable {

    /// 指定キーの `Codable` 値を読み込む。
    ///
    /// - Returns: デコードした値。キーが存在しない場合は `nil`。
    /// - Throws: 格納データのデコードに失敗した場合は ``PersistenceError/decodingFailed(key:reason:)``。
    func value<T: Codable & Sendable>(forKey key: String, type: T.Type) async throws -> T?

    /// 指定キーに `Codable` 値を書き込む。
    ///
    /// - Throws: 値のエンコードに失敗した場合は ``PersistenceError/encodingFailed(key:reason:)``。
    func setValue<T: Codable & Sendable>(_ value: T, forKey key: String) async throws

    /// 指定キーの値を削除する。キーが存在しない場合もエラーにならない。
    func removeValue(forKey key: String) async throws

    /// 指定キーに値が存在する場合に `true` を返す。
    func contains(key: String) async -> Bool
}

// MARK: - Convenience Extensions

extension KeyValueStore {

    /// `String` 値を読み込む。
    public func string(forKey key: String) async throws -> String? {
        try await value(forKey: key, type: String.self)
    }

    /// `Bool` 値を読み込む。
    public func bool(forKey key: String) async throws -> Bool? {
        try await value(forKey: key, type: Bool.self)
    }

    /// `Data` 値を読み込む。
    public func data(forKey key: String) async throws -> Data? {
        try await value(forKey: key, type: Data.self)
    }

    /// `Int` 値を読み込む。
    public func int(forKey key: String) async throws -> Int? {
        try await value(forKey: key, type: Int.self)
    }

    /// `Double` 値を読み込む。
    public func double(forKey key: String) async throws -> Double? {
        try await value(forKey: key, type: Double.self)
    }
}
