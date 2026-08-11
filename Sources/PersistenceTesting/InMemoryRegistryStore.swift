import Foundation
import PersistenceCore

/// Holds a registry in memory, for use in tests.
///
/// Nothing is encoded and nothing is written, so entries come back as the exact values that went
/// in and a type that would fail to encode still round-trips. Nothing survives the process.
///
/// The file-backed store answers an unreadable registry with an empty dictionary; this one has no
/// such failure to answer with, so a test for that path needs the real store.
///
/// Being an actor, it is safe to share between tasks.
public actor InMemoryRegistryStore<Entry: Codable & Sendable>: RegistryStore {

    private var registry: [String: Entry] = [:]

    public init() {}

    /// Creates a registry already holding these entries.
    public init(_ initial: [String: Entry]) {
        self.registry = initial
    }

    public func load() -> [String: Entry] {
        registry
    }

    public func save(_ registry: [String: Entry]) throws {
        self.registry = registry
    }

    /// How many entries the registry holds, so a test can assert on the size without reading it.
    public var count: Int {
        registry.count
    }
}
