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
    /// **Nothing stored yet and unreadable are two different answers.** A registry that was never
    /// written comes back empty; one that is there but cannot be read or decoded throws.
    ///
    /// The distinction is the point. ``save(_:)`` replaces the file wholesale, so a read that
    /// answered a broken registry with an empty dictionary would let the usual load-mutate-save
    /// cycle write that emptiness back over data that was still recoverable by hand — the failure
    /// destroying the evidence of itself. A schema change to `Entry` is exactly this case, and
    /// throwing is what stops the cycle before the save.
    ///
    /// - Returns: Every entry stored, or an empty dictionary when nothing has been stored yet.
    /// - Throws: ``PersistenceError/decodingFailed(key:reason:)`` when the stored registry does
    ///   not decode into `Entry`, or ``PersistenceError/storageFailed(operation:reason:)`` when it
    ///   cannot be read at all.
    func load() async throws -> [String: Entry]

    /// Writes the whole registry, replacing what was there.
    ///
    /// A replacement, not a merge: keys absent from the argument are gone afterwards. It is also a
    /// replacement of whatever could not be read — **saving after ``load()`` threw discards the
    /// unreadable registry**, so recover or copy it first if it matters.
    ///
    /// Implementations replace it atomically, so a reader sees either the previous contents or
    /// the new ones and never a partial write.
    ///
    /// - Throws: ``PersistenceError/encodingFailed(key:reason:)`` when an entry cannot be
    ///   encoded, or ``PersistenceError/storageFailed(operation:reason:)`` when the write fails.
    func save(_ registry: [String: Entry]) async throws
}
