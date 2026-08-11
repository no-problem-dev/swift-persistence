import Foundation

/// Small keyed values that outlive a launch: settings, flags, timestamps.
///
/// Wrapping the defaults database behind a protocol is what lets a test hand the same code an
/// in-memory double. It suits values small enough to keep in memory for the life of the process;
/// whole records belong in ``DocumentStore``.
///
/// This is not a security boundary. The shipped implementation writes a plain property list
/// inside the app container that anything with access to the container can read, and that goes
/// into backups. Secrets belong in ``SecureStore``.
///
/// Implementations: ``UserDefaultsKeyValueStore``, ``InMemoryKeyValueStore``.
public protocol KeyValueStore: Sendable {

    /// Reads what a key holds and decodes it as the requested type.
    ///
    /// - Returns: `nil` when the key holds nothing.
    /// - Throws: ``PersistenceError/decodingFailed(key:reason:)`` when bytes are present but do
    ///   not decode into `T`. An implementation that hands primitives to its backing store
    ///   unencoded may answer a type mismatch with `nil` instead of throwing, so a `nil` here is
    ///   not proof that the key is empty.
    func value<T: Codable & Sendable>(forKey key: String, type: T.Type) async throws -> T?

    /// Writes a value under a key, replacing whatever it held.
    ///
    /// Returning does not mean the value has reached disk. When it does is up to the
    /// implementation.
    ///
    /// - Throws: ``PersistenceError/encodingFailed(key:reason:)``.
    func setValue<T: Codable & Sendable>(_ value: T, forKey key: String) async throws

    /// Removes what a key holds. Removing a key that holds nothing is not an error.
    func removeValue(forKey key: String) async throws

    /// Reports whether a key holds a value, without decoding it.
    func contains(key: String) async -> Bool
}

// MARK: - Convenience Extensions

extension KeyValueStore {

    public func string(forKey key: String) async throws -> String? {
        try await value(forKey: key, type: String.self)
    }

    /// Reads a Boolean, distinguishing a key that was never set from one holding false.
    public func bool(forKey key: String) async throws -> Bool? {
        try await value(forKey: key, type: Bool.self)
    }

    public func data(forKey key: String) async throws -> Data? {
        try await value(forKey: key, type: Data.self)
    }

    /// Reads an integer, distinguishing a key that was never set from one holding zero.
    public func int(forKey key: String) async throws -> Int? {
        try await value(forKey: key, type: Int.self)
    }

    /// Reads a floating-point value, distinguishing a key that was never set from one holding zero.
    public func double(forKey key: String) async throws -> Double? {
        try await value(forKey: key, type: Double.self)
    }
}
