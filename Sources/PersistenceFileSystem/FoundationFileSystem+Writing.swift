import Foundation
import PersistenceCore

/// `FileManager` をバックエンドとする ``FileSystemWriting`` 実装。読み取り側と対になる。
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
