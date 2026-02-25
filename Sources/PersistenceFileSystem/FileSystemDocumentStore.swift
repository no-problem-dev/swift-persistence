import Foundation
import PersistenceCore

/// ``DocumentStore`` backed by individual JSON files on disk.
///
/// Each document is saved as `{id}.json` in the configured directory.
/// All file writes are atomic to prevent corruption.
public struct FileSystemDocumentStore<T: Codable & Identifiable & Sendable>: DocumentStore, Sendable
    where T.ID: CustomStringConvertible & Sendable
{
    public typealias Document = T

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Creates a file-system document store.
    ///
    /// - Parameters:
    ///   - directory: The directory to store document files. Created if it doesn't exist.
    ///   - encoder: Custom JSON encoder. Defaults to ISO 8601 dates, pretty-printed, sorted keys.
    ///   - decoder: Custom JSON decoder. Defaults to ISO 8601 dates.
    /// - Throws: ``PersistenceError/directoryCreationFailed(path:reason:)`` if the directory
    ///   cannot be created.
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
