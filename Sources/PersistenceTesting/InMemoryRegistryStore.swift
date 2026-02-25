import Foundation
import PersistenceCore

/// In-memory ``RegistryStore`` for testing.
///
/// Thread-safe via `NSLock`. Simulates the JSON registry file pattern.
public final class InMemoryRegistryStore<Entry: Codable & Sendable>: RegistryStore,
    @unchecked Sendable
{
    private var registry: [String: Entry] = [:]
    private let lock = NSLock()

    public init() {}

    /// Creates a pre-populated registry store.
    public init(_ initial: [String: Entry]) {
        self.registry = initial
    }

    public func load() -> [String: Entry] {
        lock.lock()
        defer { lock.unlock() }
        return registry
    }

    public func save(_ registry: [String: Entry]) throws {
        lock.lock()
        defer { lock.unlock() }
        self.registry = registry
    }

    /// Returns the number of entries (for test assertions).
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return registry.count
    }
}
