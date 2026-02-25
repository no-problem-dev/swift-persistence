import Foundation
import PersistenceCore

/// In-memory ``SecureStore`` for testing.
///
/// Thread-safe via `NSLock`. Simulates Keychain behavior without
/// requiring entitlements or a real Keychain.
public final class InMemorySecureStore: SecureStore, @unchecked Sendable {

    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func getString(forKey key: String) throws -> String? {
        guard let data = try getData(forKey: key) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.decodingFailed(
                key: key,
                reason: "Stored data is not valid UTF-8"
            )
        }
        return string
    }

    public func setString(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw PersistenceError.encodingFailed(
                key: key,
                reason: "String to UTF-8 conversion failed"
            )
        }
        try setData(data, forKey: key)
    }

    public func getData(forKey key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    public func setData(_ value: Data, forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = value
    }

    public func remove(forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    public func contains(key: String) throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return storage[key] != nil
    }

    /// Returns the number of stored entries (for test assertions).
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
}
