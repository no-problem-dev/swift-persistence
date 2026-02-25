import Foundation
import PersistenceCore

/// In-memory ``DocumentStore`` for testing.
///
/// Thread-safe via `NSLock`. Documents are stored in a dictionary keyed by ID.
public final class InMemoryDocumentStore<T: Codable & Identifiable & Sendable>: DocumentStore,
    @unchecked Sendable
    where T.ID: CustomStringConvertible & Hashable & Sendable
{
    public typealias Document = T

    private var documents: [T.ID: T] = [:]
    private let lock = NSLock()

    public init() {}

    public func save(_ document: T) throws {
        lock.lock()
        defer { lock.unlock() }
        documents[document.id] = document
    }

    public func load(id: T.ID) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        guard let document = documents[id] else {
            throw PersistenceError.notFound(key: "\(id)")
        }
        return document
    }

    public func loadAll() throws -> [T] {
        lock.lock()
        defer { lock.unlock() }
        return Array(documents.values)
    }

    public func delete(id: T.ID) throws {
        lock.lock()
        defer { lock.unlock() }
        guard documents.removeValue(forKey: id) != nil else {
            throw PersistenceError.notFound(key: "\(id)")
        }
    }

    public func exists(id: T.ID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return documents[id] != nil
    }

    /// Returns the number of stored documents (for test assertions).
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return documents.count
    }
}
