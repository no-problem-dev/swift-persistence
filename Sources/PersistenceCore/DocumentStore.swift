import Foundation

/// Storage for whole values addressed by their own identifier, one record per value.
///
/// Each document is read and written on its own, so a record is only ever as consistent as one
/// value. Nothing is transactional: a failure part-way through a sequence of calls leaves the
/// earlier ones applied, and there is no way to write several documents together.
///
/// The methods are `async` so an implementation can keep blocking I/O off the caller's actor.
/// Both shipped implementations are actors and do exactly that.
///
/// Implementations: ``FileSystemDocumentStore``, ``InMemoryDocumentStore``.
public protocol DocumentStore<Document>: Sendable {
    associatedtype Document: Codable & Identifiable & Sendable
        where Document.ID: CustomStringConvertible & Sendable

    /// Writes a document, replacing any document already held under the same identifier.
    ///
    /// - Throws: ``PersistenceError/encodingFailed(key:reason:)`` when the document cannot be
    ///   encoded, ``PersistenceError/storageFailed(operation:reason:)`` when the write fails.
    func save(_ document: Document) async throws

    /// Reads one document by identifier.
    ///
    /// - Throws: ``PersistenceError/notFound(key:)`` when nothing is held under the identifier,
    ///   ``PersistenceError/decodingFailed(key:reason:)`` when the stored bytes no longer decode
    ///   into `Document`. Nothing is deleted or repaired on a decoding failure.
    func load(id: Document.ID) async throws -> Document

    /// Reads every stored document, in an order that is not defined.
    ///
    /// An empty store gives an empty array. An implementation is allowed to skip records it
    /// cannot decode rather than failing the whole call, so a result shorter than expected is not
    /// by itself an error. Check the implementation before relying on the count.
    func loadAll() async throws -> [Document]

    /// Removes the document held under an identifier.
    ///
    /// - Throws: ``PersistenceError/notFound(key:)`` when nothing is held under the identifier.
    ///   Deleting twice is an error rather than a no-op.
    func delete(id: Document.ID) async throws

    /// Reports whether a record is present, without reading or decoding it.
    ///
    /// A `true` answer does not promise that ``load(id:)`` will succeed, since the record may
    /// still fail to decode.
    func exists(id: Document.ID) async -> Bool
}
