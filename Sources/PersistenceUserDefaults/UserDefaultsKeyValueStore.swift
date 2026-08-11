import Foundation
import PersistenceCore

/// Keeps values in the user defaults database, standard or in a named suite.
///
/// Strings, Booleans, integers, doubles and data go in as themselves, so anything else reading
/// the same defaults sees ordinary values, including code that never used this package. Every
/// other `Codable` type is JSON-encoded into a data value, which is opaque to such readers.
///
/// This is not a security boundary. Values land in a plain property list inside the app
/// container, readable by anything with access to it, and they go into backups. Secrets belong
/// in a `SecureStore`.
///
/// A write updates the in-memory database at once and reaches disk when the system next flushes
/// it, which is not before the call returns. A process killed in between loses the write; a
/// normal termination does not.
///
/// Being an actor, calls are serialised and the shared encoder and decoder are never used
/// concurrently. The defaults calls themselves are in-memory and quick, so the actor is rarely a
/// bottleneck.
public actor UserDefaultsKeyValueStore: KeyValueStore {

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a store over the standard defaults, or over a shared suite.
    ///
    /// - Parameter suiteName: An app group or shared suite identifier, which is what lets an
    ///   extension or another app in the same group read the same values. A name the system
    ///   rejects, such as the app's own bundle identifier or the global domain, quietly falls
    ///   back to the standard database rather than failing, so values then go somewhere other
    ///   than intended.
    public init(suiteName: String? = nil) {
        self.defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// Reads a value, using the defaults database's own accessors for the five primitive types.
    ///
    /// A key holding nothing gives `nil` rather than the type's zero value, unlike the underlying
    /// `bool(forKey:)` and `integer(forKey:)`, which cannot tell the two apart.
    ///
    /// Only the JSON path fails loudly. Asking for a primitive type against a key holding a
    /// different kind of value gives `nil`, except for Booleans and numbers, where the defaults
    /// database coerces what it finds: a key holding the string "1" reads back as `true`.
    ///
    /// - Throws: ``PersistenceError/decodingFailed(key:reason:)`` when a non-primitive type's
    ///   stored data does not decode. The data stays where it is, so the read keeps failing until
    ///   the key is overwritten or removed.
    public func value<T: Codable & Sendable>(forKey key: String, type: T.Type) throws -> T? {
        // Primitive fast path: keep these in the defaults database's own representation, so other
        // readers of the same defaults see ordinary values rather than JSON blobs.
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

        // Everything else was stored as JSON.
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PersistenceError.decodingFailed(key: key, reason: error.localizedDescription)
        }
    }

    /// Writes a value, storing the five primitive types as themselves and the rest as JSON.
    ///
    /// The value is in the database when this returns, but not yet on disk. Writing a type the
    /// defaults database cannot hold natively, then reading it back as a primitive, gives `nil`,
    /// because the two paths do not meet.
    public func setValue<T: Codable & Sendable>(_ value: T, forKey key: String) throws {
        // Primitive fast path, mirroring the one in `value(forKey:type:)`.
        if let s = value as? String { defaults.set(s, forKey: key); return }
        if let b = value as? Bool { defaults.set(b, forKey: key); return }
        if let i = value as? Int { defaults.set(i, forKey: key); return }
        if let d = value as? Double { defaults.set(d, forKey: key); return }
        if let data = value as? Data { defaults.set(data, forKey: key); return }

        // Everything else goes in as JSON.
        do {
            let data = try encoder.encode(value)
            defaults.set(data, forKey: key)
        } catch {
            throw PersistenceError.encodingFailed(key: key, reason: error.localizedDescription)
        }
    }

    /// Removes the key's value from the app's own domain.
    ///
    /// A value supplied through `register(defaults:)` becomes visible again afterwards, since
    /// only the written value is deleted.
    public func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
    }

    /// Reports whether the key resolves to a value in any domain, registered defaults included.
    ///
    /// A key that only has a registered default counts as present here even though nothing was
    /// ever written for it.
    public func contains(key: String) -> Bool {
        defaults.object(forKey: key) != nil
    }
}
