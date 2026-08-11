import Foundation
import PersistenceCore

/// Keeps secrets in a dictionary, for use in tests.
///
/// Nothing is encrypted, nothing is written and nothing survives the process. It stands in for
/// the Keychain so tests can run without entitlements, a signed bundle or a device.
///
/// Only the success paths are modelled: reads never fail, so nothing here exercises the
/// locked-device or missing-entitlement errors the real store raises. The one failure it does
/// reproduce is reading back a stored value that is not valid UTF-8 as a string.
///
/// Being an actor, it is safe to share between tasks.
public actor InMemorySecureStore: SecureStore {

    private var storage: [String: Data] = [:]

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
        storage[key]
    }

    public func setData(_ value: Data, forKey key: String) throws {
        storage[key] = value
    }

    public func remove(forKey key: String) {
        storage.removeValue(forKey: key)
    }

    public func contains(key: String) throws -> Bool {
        storage[key] != nil
    }

    /// How many keys hold a value, so a test can assert on the size without listing them.
    public var count: Int {
        storage.count
    }
}
