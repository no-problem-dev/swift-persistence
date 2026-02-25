import Foundation

/// Type-safe key-value storage abstraction.
///
/// Abstracts `UserDefaults` and similar KV stores behind a protocol
/// for dependency injection and testability.
///
/// Implementations: ``UserDefaultsKeyValueStore``, ``InMemoryKeyValueStore``.
public protocol KeyValueStore: Sendable {

    /// Reads a Codable value for the given key.
    ///
    /// - Returns: The decoded value, or `nil` if the key does not exist.
    /// - Throws: ``PersistenceError/decodingFailed(key:reason:)`` if stored data cannot be decoded.
    func value<T: Codable & Sendable>(forKey key: String, type: T.Type) throws -> T?

    /// Writes a Codable value for the given key.
    ///
    /// - Throws: ``PersistenceError/encodingFailed(key:reason:)`` if the value cannot be encoded.
    func setValue<T: Codable & Sendable>(_ value: T, forKey key: String) throws

    /// Removes the value for the given key. Does not throw if the key does not exist.
    func removeValue(forKey key: String) throws

    /// Returns `true` if a value exists for the given key.
    func contains(key: String) -> Bool
}

// MARK: - Convenience Extensions

extension KeyValueStore {

    /// Reads a `String` value.
    public func string(forKey key: String) throws -> String? {
        try value(forKey: key, type: String.self)
    }

    /// Reads a `Bool` value.
    public func bool(forKey key: String) throws -> Bool? {
        try value(forKey: key, type: Bool.self)
    }

    /// Reads a `Data` value.
    public func data(forKey key: String) throws -> Data? {
        try value(forKey: key, type: Data.self)
    }

    /// Reads an `Int` value.
    public func int(forKey key: String) throws -> Int? {
        try value(forKey: key, type: Int.self)
    }

    /// Reads a `Double` value.
    public func double(forKey key: String) throws -> Double? {
        try value(forKey: key, type: Double.self)
    }
}
