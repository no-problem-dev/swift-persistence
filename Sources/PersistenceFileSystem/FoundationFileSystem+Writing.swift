import Foundation
import PersistenceCore

/// The writing half of the disk-backed file tree.
///
/// Every write creates the missing parent directories first, replaces files atomically, and
/// treats deleting something absent as success. None of it is flushed, so the bytes are only as
/// durable as the file system's own scheduling.
///
/// A call that takes more than one step is not undone if a later step fails: a move whose
/// destination directory was created but whose rename then failed leaves the empty directory
/// behind.
extension FoundationFileSystem: FileSystemWriting {

    public func createDirectory(_ url: URL) async throws {
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true
            )
        } catch {
            throw PersistenceError.directoryCreationFailed(
                path: url.path,
                reason: error.localizedDescription
            )
        }
    }

    public func write(_ data: Data, to url: URL) async throws {
        try await createDirectory(url.deletingLastPathComponent())
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw PersistenceError.storageFailed(
                operation: "write(\(url.path))",
                reason: error.localizedDescription
            )
        }
    }

    public func removeItem(_ url: URL) async throws {
        guard await exists(url) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw PersistenceError.storageFailed(
                operation: "removeItem(\(url.path))",
                reason: error.localizedDescription
            )
        }
    }

    public func moveItem(from source: URL, to destination: URL) async throws {
        guard await exists(source) else {
            throw PersistenceError.notFound(key: source.path)
        }
        guard await exists(destination) == false else {
            throw PersistenceError.storageFailed(
                operation: "moveItem(\(source.path) -> \(destination.path))",
                reason: "Destination already exists"
            )
        }
        try await createDirectory(destination.deletingLastPathComponent())
        do {
            try FileManager.default.moveItem(at: source, to: destination)
        } catch {
            throw PersistenceError.storageFailed(
                operation: "moveItem(\(source.path) -> \(destination.path))",
                reason: error.localizedDescription
            )
        }
    }
}
