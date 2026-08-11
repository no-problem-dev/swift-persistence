import Foundation

/// A whole map of keyed entries, read and written as one unit.
///
/// This suits a registry small enough to hold in memory and rewrite in full, such as a cache
/// index. The expected shape is that a consumer, usually an actor, reads the map once at
/// start-up, keeps it in memory, mutates it, and writes the whole thing back after each change.
/// There is no per-entry read or write.
///
/// Keys are dictionary keys, so duplicates cannot arise and no order is kept. A caller that
/// wants a stable order has to sort the keys itself.
///
/// Implementations: ``FileSystemRegistryStore``, ``InMemoryRegistryStore``.
public protocol RegistryStore<Entry>: Sendable {
    associatedtype Entry: Codable & Sendable

    /// Reads the whole registry.
    ///
    /// This cannot fail. A registry that is missing, unreadable or corrupt all arrive as an empty
    /// dictionary, indistinguishable from one that was never written. A caller that has to tell
    /// "empty" from "broken" must look at the backing storage itself.
    func load() async -> [String: Entry]

    /// Writes the whole registry, replacing what was there.
    ///
    /// A replacement, not a merge: keys absent from the argument are gone afterwards.
    /// Implementations replace it atomically, so a reader sees either the previous contents or
    /// the new ones and never a partial write.
    ///
    /// - Throws: ``PersistenceError/encodingFailed(key:reason:)`` when an entry cannot be
    ///   encoded, or ``PersistenceError/storageFailed(operation:reason:)`` when the write fails.
    func save(_ registry: [String: Entry]) async throws
}
