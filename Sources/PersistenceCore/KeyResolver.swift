import Foundation

/// Resolves a value by trying multiple sources in priority order.
///
/// Abstracts the common pattern of checking Info.plist, then Keychain,
/// then UserDefaults for a configuration value.
///
/// Implementations: ``ChainedKeyResolver``, ``InMemoryKeyResolver``.
public protocol KeyResolver: Sendable {

    /// Resolves a string value for the given logical key.
    ///
    /// - Returns: The resolved value, or `nil` if no source has a value.
    func resolve(_ key: String) -> String?
}

/// Resolves values by checking sources in order: Info.plist → SecureStore → KeyValueStore.
public struct ChainedKeyResolver: KeyResolver, Sendable {

    private let infoPlistLookup: @Sendable (String) -> String?
    private let secureStore: any SecureStore
    private let keyValueStore: any KeyValueStore

    /// Maps logical key names to their storage keys in each store.
    ///
    /// Example: `"ANTHROPIC_API_KEY"` → `(secure: "anthropic_api_key", kv: "anthropic_api_key")`
    private let keyMapping: [String: StorageKeys]

    /// Storage key pair for a logical key.
    public struct StorageKeys: Sendable {
        public let secure: String
        public let keyValue: String

        public init(secure: String, keyValue: String) {
            self.secure = secure
            self.keyValue = keyValue
        }
    }

    /// Creates a chained key resolver.
    ///
    /// - Parameters:
    ///   - infoPlistLookup: Closure to look up values in Info.plist.
    ///     Defaults to `Bundle.main.infoDictionary` lookup.
    ///   - secureStore: Secure storage (Keychain) to check second.
    ///   - keyValueStore: Key-value storage (UserDefaults) to check last (migration fallback).
    ///   - keyMapping: Maps logical key names to their storage keys.
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

    public func resolve(_ key: String) -> String? {
        // 1. Info.plist (build-time injection via xcconfig)
        if let value = infoPlistLookup(key),
           !value.isEmpty,
           !value.hasPrefix("$(") {
            return value
        }

        guard let mapping = keyMapping[key] else { return nil }

        // 2. SecureStore (Keychain)
        if let value = try? secureStore.getString(forKey: mapping.secure),
           !value.isEmpty {
            return value
        }

        // 3. KeyValueStore (UserDefaults — legacy fallback during migration)
        if let value = try? keyValueStore.string(forKey: mapping.keyValue),
           !value.isEmpty {
            return value
        }

        return nil
    }
}
