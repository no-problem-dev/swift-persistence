import Foundation

/// File-based CRUD storage for identifiable Codable documents.
///
/// Each document is persisted individually (e.g., as `{id}.json`) and
/// can be loaded, saved, listed, or deleted by ID.
///
/// All methods are `async` so that implementations (especially file-backed ones)
/// can perform I/O off the caller's actor (e.g., `@MainActor`).
///
/// Implementations: ``FileSystemDocumentStore``, ``InMemoryDocumentStore``.
public protocol DocumentStore<Document>: Sendable {
    associatedtype Document: Codable & Identifiable & Sendable
        where Document.ID: CustomStringConvertible & Sendable

    /// Saves a document, creating or overwriting it.
    func save(_ document: Document) async throws

    /// Loads a single document by its ID.
    ///
    /// - Throws: ``PersistenceError/notFound(key:)`` if no document with the given ID exists.
    func load(id: Document.ID) async throws -> Document

    /// Loads all documents.
    ///
    /// Returns an empty array if no documents exist.
    func loadAll() async throws -> [Document]

    /// Deletes a document by ID.
    ///
    /// - Throws: ``PersistenceError/notFound(key:)`` if no document with the given ID exists.
    func delete(id: Document.ID) async throws

    /// Returns `true` if a document with the given ID exists.
    func exists(id: Document.ID) async -> Bool
}
