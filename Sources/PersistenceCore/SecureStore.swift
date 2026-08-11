import Foundation

/// Storage for credentials, kept out of the app's own files and encrypted at rest.
///
/// Use it for anything that would be damaging to read out of a backup: API keys, auth tokens,
/// passwords. Ordinary settings belong in ``KeyValueStore``, which has no protection at all.
///
/// Only strings and raw bytes are offered, which is the shape credentials arrive in. There is no
/// `Codable` overload.
///
/// Implementations: ``KeychainSecureStore``, ``InMemorySecureStore``.
public protocol SecureStore: Sendable {

    /// Reads a string from secure storage.
    ///
    /// - Returns: `nil` when the key holds nothing.
    /// - Throws: ``PersistenceError/decodingFailed(key:reason:)`` when the stored bytes are not
    ///   valid UTF-8. The bytes stay where they are, and ``getData(forKey:)`` can still recover
    ///   them.
    func getString(forKey key: String) async throws -> String?

    /// Writes a string as its UTF-8 bytes, replacing whatever the key held.
    func setString(_ value: String, forKey key: String) async throws

    /// Reads raw bytes from secure storage.
    ///
    /// - Returns: `nil` when the key holds nothing.
    func getData(forKey key: String) async throws -> Data?

    /// Writes raw bytes, replacing whatever the key held.
    func setData(_ value: Data, forKey key: String) async throws

    /// Removes what a key holds. Removing a key that holds nothing is not an error.
    func remove(forKey key: String) async throws

    /// Reports whether a key holds a value.
    ///
    /// The Keychain-backed implementation answers by reading the item, so this costs what
    /// ``getData(forKey:)`` costs and fails in the same situations.
    func contains(key: String) async throws -> Bool
}
