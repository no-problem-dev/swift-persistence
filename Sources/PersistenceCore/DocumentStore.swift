import Foundation

/// File-based CRUD storage for identifiable Codable documents.
///
/// Each document is persisted individually (e.g., as `{id}.json`) and
/// can be loaded, saved, listed, or deleted by ID.
///
/// Implementations: ``FileSystemDocumentStore``, ``InMemoryDocumentStore``.
public protocol DocumentStore<Document>: Sendable {
    associatedtype Document: Codable & Identifiable & Sendable
        where Document.ID: CustomStringConvertible & Sendable

    /// Saves a document, creating or overwriting it.
    func save(_ document: Document) throws

    /// Loads a single document by its ID.
    ///
    /// - Throws: ``PersistenceError/notFound(key:)`` if no document with the given ID exists.
    func load(id: Document.ID) throws -> Document

    /// Loads all documents.
    ///
    /// Returns an empty array if no documents exist.
    func loadAll() throws -> [Document]

    /// Deletes a document by ID.
    ///
    /// - Throws: ``PersistenceError/notFound(key:)`` if no document with the given ID exists.
    func delete(id: Document.ID) throws

    /// Returns `true` if a document with the given ID exists.
    func exists(id: Document.ID) -> Bool
}
