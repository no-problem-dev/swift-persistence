import Foundation
import PersistenceCore

/// In-memory ``KeyValueStore`` for testing.
///
/// Actor isolation replaces manual `NSLock` synchronization,
/// providing data-race safety with cleaner code.
public actor InMemoryKeyValueStore: KeyValueStore {

    private var storage: [String: Data] = [:]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// Creates an in-memory store pre-populated with the given values.
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

    /// Returns the number of stored entries (for test assertions).
    public var count: Int {
        storage.count
    }
}

// MARK: - CodableWrapper

/// Helper to encode `any Codable` values for initial population.
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
