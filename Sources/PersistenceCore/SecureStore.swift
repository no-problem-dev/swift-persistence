import Foundation

/// Abstraction for secure credential storage (Keychain).
///
/// Stores sensitive values like API keys in encrypted storage.
/// Unlike ``KeyValueStore``, this protocol focuses on string and data values
/// commonly used for secrets and tokens.
///
/// All methods are `async` so that implementations can perform I/O
/// off the caller's actor (e.g., `@MainActor`).
///
/// Implementations: ``KeychainSecureStore``, ``InMemorySecureStore``.
public protocol SecureStore: Sendable {

    /// Reads a string value from secure storage.
    ///
    /// - Returns: The stored string, or `nil` if the key does not exist.
    func getString(forKey key: String) async throws -> String?

    /// Writes a string value to secure storage.
    /// Overwrites any existing value for the same key.
    func setString(_ value: String, forKey key: String) async throws

    /// Reads raw data from secure storage.
    ///
    /// - Returns: The stored data, or `nil` if the key does not exist.
    func getData(forKey key: String) async throws -> Data?

    /// Writes raw data to secure storage.
    /// Overwrites any existing value for the same key.
    func setData(_ value: Data, forKey key: String) async throws

    /// Removes the value for the given key. Does not throw if the key does not exist.
    func remove(forKey key: String) async throws

    /// Returns `true` if a value exists for the given key.
    func contains(key: String) async throws -> Bool
}
