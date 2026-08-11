import Foundation
import PersistenceCore

/// Holds documents in a dictionary for the life of the process, for use in tests.
///
/// Nothing is written anywhere and nothing survives the process: every instance starts empty.
/// Documents are kept as values rather than encoded, so a type that would fail to encode or
/// decode still round-trips here. A test that passes against this store is therefore no proof
/// that the disk-backed one will work.
///
/// The missing-document cases do match the disk-backed store, so tests for those paths are worth
/// writing here.
///
/// Being an actor, it is safe to share between tasks.
public actor InMemoryDocumentStore<T: Codable & Identifiable & Sendable>: DocumentStore
    where T.ID: CustomStringConvertible & Hashable & Sendable
{
    public typealias Document = T

    private var documents: [T.ID: T] = [:]

    public init() {}

    public func save(_ document: T) throws {
        documents[document.id] = document
    }

    public func load(id: T.ID) throws -> T {
        guard let document = documents[id] else {
            throw PersistenceError.notFound(key: "\(id)")
        }
        return document
    }

    /// Reads every document, in an order that varies between runs.
    ///
    /// The order is the dictionary's, so a test that compares the result against a literal array
    /// has to sort it first.
    public func loadAll() throws -> [T] {
        Array(documents.values)
    }

    public func delete(id: T.ID) throws {
        guard documents.removeValue(forKey: id) != nil else {
            throw PersistenceError.notFound(key: "\(id)")
        }
    }

    public func exists(id: T.ID) -> Bool {
        documents[id] != nil
    }

    /// How many documents are held, so a test can assert on the size without listing them.
    public var count: Int {
        documents.count
    }
}
