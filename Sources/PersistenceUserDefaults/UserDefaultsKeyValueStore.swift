import Foundation
import PersistenceCore

/// ``KeyValueStore`` backed by `UserDefaults`.
///
/// Primitive types (`String`, `Bool`, `Int`, `Double`, `Data`) use
/// UserDefaults' native accessors for efficiency. All other `Codable` types
/// are round-tripped through `JSONEncoder`/`JSONDecoder`.
public final class UserDefaultsKeyValueStore: KeyValueStore, @unchecked Sendable {

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a UserDefaults-backed key-value store.
    ///
    /// - Parameter suiteName: Optional suite name for a shared `UserDefaults` container.
    ///   Pass `nil` to use `.standard`.
    public init(suiteName: String? = nil) {
        self.defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func value<T: Codable & Sendable>(forKey key: String, type: T.Type) throws -> T? {
        // Fast path for primitive types
        if type == String.self {
            return defaults.string(forKey: key) as? T
        }
        if type == Bool.self {
            guard defaults.object(forKey: key) != nil else { return nil }
            return defaults.bool(forKey: key) as? T
        }
        if type == Int.self {
            guard defaults.object(forKey: key) != nil else { return nil }
            return defaults.integer(forKey: key) as? T
        }
        if type == Double.self {
            guard defaults.object(forKey: key) != nil else { return nil }
            return defaults.double(forKey: key) as? T
        }
        if type == Data.self {
            return defaults.data(forKey: key) as? T
        }

        // Codable path
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PersistenceError.decodingFailed(key: key, reason: error.localizedDescription)
        }
    }

    public func setValue<T: Codable & Sendable>(_ value: T, forKey key: String) throws {
        // Fast path for primitive types
        if let s = value as? String { defaults.set(s, forKey: key); return }
        if let b = value as? Bool { defaults.set(b, forKey: key); return }
        if let i = value as? Int { defaults.set(i, forKey: key); return }
        if let d = value as? Double { defaults.set(d, forKey: key); return }
        if let data = value as? Data { defaults.set(data, forKey: key); return }

        // Codable path
        do {
            let data = try encoder.encode(value)
            defaults.set(data, forKey: key)
        } catch {
            throw PersistenceError.encodingFailed(key: key, reason: error.localizedDescription)
        }
    }

    public func removeValue(forKey key: String) throws {
        defaults.removeObject(forKey: key)
    }

    public func contains(key: String) -> Bool {
        defaults.object(forKey: key) != nil
    }
}
