import Foundation

/// The one error every store in this package throws.
///
/// Each case names what failed and carries the underlying reason as text. The original error is
/// not retained, so a caller can report the failure but cannot inspect or re-throw the platform
/// error behind it.
public enum PersistenceError: Error, Sendable, Equatable {

    /// Nothing is stored under this key.
    ///
    /// Only reads that return a non-optional value throw this. Reads that return an optional
    /// signal the same condition with `nil`.
    case notFound(key: String)

    /// The value could not be turned into bytes, so nothing was written.
    case encodingFailed(key: String, reason: String)

    /// Bytes were found but did not decode into the requested type.
    ///
    /// The stored bytes are left untouched, so the same read keeps failing until the key is
    /// overwritten or removed. This is what a schema change looks like from the read side.
    case decodingFailed(key: String, reason: String)

    /// The backing store refused the operation, or failed part-way through it.
    case storageFailed(operation: String, reason: String)

    /// The Keychain answered with a status other than success or "item not found".
    ///
    /// The reason carries the raw `OSStatus`, and not every value means a permission problem: a
    /// read attempted while the device is locked and a query the Keychain rejected both arrive
    /// here alongside a missing entitlement.
    case accessDenied(reason: String)

    /// A directory a store needs could not be created, leaving the store unusable.
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
