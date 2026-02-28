import Foundation

/// JSON-backed registry for keyed entries.
///
/// Generalizes the pattern used by model cache and adapter cache registries
/// where a single JSON file maps string keys to metadata entries.
///
/// The consuming code (typically an actor) holds the in-memory dictionary and
/// calls `load()` on init and `save(_:)` after mutations.
///
/// All methods are `async` so that implementations can perform I/O
/// off the caller's actor (e.g., `@MainActor`).
///
/// Implementations: ``FileSystemRegistryStore``, ``InMemoryRegistryStore``.
public protocol RegistryStore<Entry>: Sendable {
    associatedtype Entry: Codable & Sendable

    /// Loads the entire registry from storage.
    ///
    /// Returns an empty dictionary if the registry does not exist or cannot be decoded.
    func load() async -> [String: Entry]

    /// Saves the entire registry to storage, atomically.
    func save(_ registry: [String: Entry]) async throws
}
