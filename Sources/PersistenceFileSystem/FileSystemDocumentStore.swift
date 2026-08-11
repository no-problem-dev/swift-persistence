import Foundation
import PersistenceCore

/// Keeps each document in its own JSON file inside a single directory.
///
/// A document's file name is its identifier followed by `.json`, so the identifier's text is
/// what a key resolves to on disk. It is used verbatim, with no escaping: an identifier holding a
/// slash lands in a subdirectory, and since only the store's own directory is created, saving it
/// fails. Identifiers must be usable as a single path component.
///
/// A save replaces the file atomically, so a reader never sees a half-written document. It is not
/// flushed, so a power loss just after a save can still lose it. Nothing is cached, so every read
/// goes to disk and picks up changes made by anything else writing the same directory.
///
/// Being an actor, calls are serialised and the file I/O runs off the caller's actor. The I/O
/// itself is synchronous, so a call holds the store's executor for the whole read or write.
public actor FileSystemDocumentStore<T: Codable & Identifiable & Sendable>: DocumentStore
    where T.ID: CustomStringConvertible & Sendable
{
    public typealias Document = T

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates the store together with the directory it will write into.
    ///
    /// - Parameters:
    ///   - directory: Where the document files go. It and any missing parents are created here,
    ///     which is the only reason this initialiser can fail.
    ///   - encoder: Defaults to ISO 8601 dates with pretty-printed, key-sorted output, which
    ///     keeps the files readable and makes successive saves diff cleanly.
    ///   - decoder: Defaults to ISO 8601 dates, matching the default encoder. Passing an encoder
    ///     and decoder whose date strategies disagree makes documents unreadable after a save.
    /// - Throws: ``PersistenceError/directoryCreationFailed(path:reason:)``.
    public init(
        directory: URL,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) throws {
        self.directory = directory

        if let encoder {
            self.encoder = encoder
        } else {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            self.encoder = enc
        }

        if let decoder {
            self.decoder = decoder
        } else {
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            self.decoder = dec
        }

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw PersistenceError.directoryCreationFailed(
                path: directory.path,
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - DocumentStore

    public func save(_ document: T) throws {
        let url = fileURL(for: document.id)
        let data: Data
        do {
            data = try encoder.encode(document)
        } catch {
            throw PersistenceError.encodingFailed(
                key: "\(document.id)",
                reason: error.localizedDescription
            )
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw PersistenceError.storageFailed(
                operation: "save",
                reason: error.localizedDescription
            )
        }
    }

    public func load(id: T.ID) throws -> T {
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PersistenceError.notFound(key: "\(id)")
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw PersistenceError.storageFailed(
                operation: "load",
                reason: error.localizedDescription
            )
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PersistenceError.decodingFailed(
                key: "\(id)",
                reason: error.localizedDescription
            )
        }
    }

    /// Reads every document in the directory, in whatever order the file system lists them.
    ///
    /// Files that cannot be read or decoded are skipped without a word, so a document left over
    /// from an older schema disappears from the result instead of failing the call. That makes a
    /// short result impossible to tell from a small store. Only files ending in `.json` are
    /// considered, and subdirectories are not descended into.
    public func loadAll() throws -> [T] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }
        } catch {
            throw PersistenceError.storageFailed(
                operation: "loadAll",
                reason: error.localizedDescription
            )
        }

        var documents: [T] = []
        for url in files {
            if let data = try? Data(contentsOf: url),
               let document = try? decoder.decode(T.self, from: data) {
                documents.append(document)
            }
        }
        return documents
    }

    public func delete(id: T.ID) throws {
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PersistenceError.notFound(key: "\(id)")
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw PersistenceError.storageFailed(
                operation: "delete",
                reason: error.localizedDescription
            )
        }
    }

    public func exists(id: T.ID) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: id).path)
    }

    // MARK: - Private

    private func fileURL(for id: T.ID) -> URL {
        directory.appendingPathComponent("\(id).json")
    }
}
