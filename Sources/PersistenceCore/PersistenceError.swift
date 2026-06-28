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

// MARK: - LocalizedError

extension PersistenceError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .notFound(let key):
            return "Item not found for key '\(key)'."
        case .encodingFailed(let key, let reason):
            return "Encoding failed for key '\(key)': \(reason)"
        case .decodingFailed(let key, let reason):
            return "Decoding failed for key '\(key)': \(reason)"
        case .storageFailed(let operation, let reason):
            return "Storage operation '\(operation)' failed: \(reason)"
        case .accessDenied(let reason):
            return "Storage access denied: \(reason)"
        case .directoryCreationFailed(let path, let reason):
            return "Could not create directory at '\(path)': \(reason)"
        }
    }
}
