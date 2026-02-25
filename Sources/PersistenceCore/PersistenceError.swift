import Foundation

/// Unified error type for all persistence operations.
public enum PersistenceError: Error, Sendable, Equatable {

    /// The requested item was not found.
    case notFound(key: String)

    /// Encoding the value for storage failed.
    case encodingFailed(key: String, reason: String)

    /// Decoding the stored data failed.
    case decodingFailed(key: String, reason: String)

    /// The underlying storage operation failed (disk, keychain, etc.).
    case storageFailed(operation: String, reason: String)

    /// Access to the storage was denied (e.g., Keychain entitlement missing).
    case accessDenied(reason: String)

    /// The storage directory could not be created.
    case directoryCreationFailed(path: String, reason: String)
}
