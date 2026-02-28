import Foundation
import PersistenceCore

/// In-memory ``RegistryStore`` for testing.
///
/// Actor isolation replaces manual `NSLock` synchronization.
/// Simulates the JSON registry file pattern.
public actor InMemoryRegistryStore<Entry: Codable & Sendable>: RegistryStore {

    private var registry: [String: Entry] = [:]

    public init() {}

    /// Creates a pre-populated registry store.
    public init(_ initial: [String: Entry]) {
        self.registry = initial
    }

    public func load() -> [String: Entry] {
        registry
    }

    public func save(_ registry: [String: Entry]) throws {
        self.registry = registry
    }

    /// Returns the number of entries (for test assertions).
    public var count: Int {
        registry.count
    }
}
