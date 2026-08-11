import Foundation

/// Looks up a configuration value by name, trying several places in a fixed order.
///
/// A setting such as an API key can arrive from more than one place depending on how the app was
/// built and what it did in earlier versions. This hides that ordering from callers, who ask for
/// a logical name and receive whatever the first place to answer held.
///
/// Implementations: ``ChainedKeyResolver``, ``InMemoryKeyResolver``.
public protocol KeyResolver: Sendable {

    /// Returns the first value found for a logical key name.
    ///
    /// - Returns: `nil` when no source held one. Resolution does not throw, so a source that
    ///   failed and a source that had nothing are indistinguishable from here.
    func resolve(_ key: String) async -> String?
}

/// Looks in the app bundle first, then secure storage, then the key-value store.
///
/// The order encodes a migration. A value compiled in at build time wins; secure storage is
/// where the value is meant to live; the key-value store is read last only so that a value
/// written by an older version is still found.
///
/// A blank value counts as absent, as does an unsubstituted build setting, so a placeholder left
/// in the bundle does not shadow a real credential further down the chain.
public struct ChainedKeyResolver: KeyResolver, Sendable {

    private let infoPlistLookup: @Sendable (String) -> String?
    private let secureStore: any SecureStore
    private let keyValueStore: any KeyValueStore

    /// Maps each logical key name onto the concrete key it has in each backing store.
    ///
    /// A name missing from this map is looked up in the bundle only; the other two sources are
    /// skipped, so an unmapped key silently resolves to `nil` even when secure storage holds it
    /// under the same name.
    private let keyMapping: [String: StorageKeys]

    /// The concrete key names one logical name has in the two backing stores.
    ///
    /// They need not match, which is what lets a value keep its legacy name in the key-value
    /// store while moving to a new one in secure storage.
    public struct StorageKeys: Sendable {
        public let secure: String
        public let keyValue: String

        public init(secure: String, keyValue: String) {
            self.secure = secure
            self.keyValue = keyValue
        }
    }

    /// Creates a resolver over the three sources, listed in the order they will be tried.
    ///
    /// - Parameters:
    ///   - infoPlistLookup: Reads a value from the app bundle. The default reads
    ///     `Bundle.main.infoDictionary`, which is normally filled from an xcconfig at build time.
    ///     Replace it in tests so resolution does not depend on the host bundle.
    ///   - secureStore: Tried second, and where values are expected to live.
    ///   - keyValueStore: Tried last, and only so that values written by an older version are
    ///     still found.
    ///   - keyMapping: The concrete key names to use in the two stores. Names absent from it are
    ///     looked up in the bundle only.
    public init(
        infoPlistLookup: @escaping @Sendable (String) -> String? = { key in
            Bundle.main.infoDictionary?[key] as? String
        },
        secureStore: any SecureStore,
        keyValueStore: any KeyValueStore,
        keyMapping: [String: StorageKeys]
    ) {
        self.infoPlistLookup = infoPlistLookup
        self.secureStore = secureStore
        self.keyValueStore = keyValueStore
        self.keyMapping = keyMapping
    }

    public func resolve(_ key: String) async -> String? {
        // 1. App bundle, normally injected at build time from an xcconfig.
        // A value still starting with "$(" is an unsubstituted build setting, not a credential.
        if let value = infoPlistLookup(key),
           !value.isEmpty,
           !value.hasPrefix("$(") {
            return value
        }

        guard let mapping = keyMapping[key] else { return nil }

        // 2. Secure storage.
        // The `try?` is deliberate: a missing entitlement or a locked device is treated as "no
        // value here" so the next source still gets its turn.
        if let value = try? await secureStore.getString(forKey: mapping.secure),
           !value.isEmpty {
            return value
        }

        // 3. Key-value store, the legacy location still read during migration.
        // Deliberate for the same reason: an entry written by an older version may no longer
        // decode, and that should read as "not here" rather than fail the lookup.
        if let value = try? await keyValueStore.string(forKey: mapping.keyValue),
           !value.isEmpty {
            return value
        }

        return nil
    }
}
