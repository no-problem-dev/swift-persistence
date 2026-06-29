import Foundation
import PersistenceCore

/// テスト用のインメモリ ``KeyValueStore``。
///
/// アクター分離によりロック同期を置き換え、データレース安全を実現する。
public actor InMemoryKeyValueStore: KeyValueStore {

    private var storage: [String: Data] = [:]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// 指定した値で初期状態を持つインメモリストアを生成する。
    public init(_ initial: [String: any Codable & Sendable]) {
        let encoder = JSONEncoder()
        self.encoder = encoder
        self.decoder = JSONDecoder()
        for (key, value) in initial {
            if let data = try? encoder.encode(CodableWrapper(value)) {
                storage[key] = data
            }
        }
    }

    public func value<T: Codable & Sendable>(forKey key: String, type: T.Type) throws -> T? {
        guard let data = storage[key] else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PersistenceError.decodingFailed(key: key, reason: error.localizedDescription)
        }
    }

    public func setValue<T: Codable & Sendable>(_ value: T, forKey key: String) throws {
        do {
            let data = try encoder.encode(value)
            storage[key] = data
        } catch {
            throw PersistenceError.encodingFailed(key: key, reason: error.localizedDescription)
        }
    }

    public func removeValue(forKey key: String) {
        storage.removeValue(forKey: key)
    }

    public func contains(key: String) -> Bool {
        storage[key] != nil
    }

    /// 格納エントリ数（テストアサーション用）。
    public var count: Int {
        storage.count
    }
}

// MARK: - CodableWrapper

/// 初期値エンコード用の `any Codable` ラッパー。
private struct CodableWrapper: Encodable {
    private let encode: (Encoder) throws -> Void

    init(_ value: any Codable) {
        self.encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}
