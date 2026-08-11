import Foundation
import PersistenceCore

/// Keeps key-value entries in memory as JSON, for use in tests.
///
/// Every value goes through `JSONEncoder` and `JSONDecoder`, strings and numbers included, which
/// makes this the stricter of the two implementations: reading a key as the wrong type throws
/// ``PersistenceError/decodingFailed(key:reason:)`` here, where the defaults-backed store would
/// answer `nil` or coerce the value. Code that passes against this store can still surprise
/// against the real one.
///
/// Nothing survives the process. Being an actor, it is safe to share between tasks.
public actor InMemoryKeyValueStore: KeyValueStore {

    private var storage: [String: Data] = [:]
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// Creates a store already holding these values.
    ///
    /// A value that fails to encode is dropped without a word, so a store built this way can hold
    /// fewer entries than were passed in.
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

    /// How many keys hold a value, so a test can assert on the size without listing them.
    public var count: Int {
        storage.count
    }
}

// MARK: - CodableWrapper

/// Carries an existential value long enough to encode it.
///
/// `any Codable` cannot be handed to `JSONEncoder` directly, so each initial value is wrapped in
/// one of these, which forwards `encode(to:)` to the value it captured.
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
