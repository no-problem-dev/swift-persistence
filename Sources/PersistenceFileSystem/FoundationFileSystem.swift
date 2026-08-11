import Foundation
import PersistenceCore

/// A file tree backed by the real local disk.
///
/// Reads go straight to `FileManager` with no caching and no sandboxing of paths: any URL the
/// process can reach is fair game, symlinks are followed, and nothing keeps a caller inside the
/// app container.
///
/// This is a value type rather than an actor because it holds no state and `FileManager.default`
/// is safe to use from several threads at once, so any number of tasks can read through it
/// concurrently. The methods are `async` but never suspend: each one does its I/O synchronously
/// and occupies a cooperative thread until the disk answers, so reading a large file blocks for
/// as long as the read takes.
public struct FoundationFileSystem: FileSystemReading {

    public init() {}

    public func exists(_ url: URL) async -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func isDirectory(_ url: URL) async -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    public func contentsOfDirectory(_ url: URL) async throws -> [URL] {
        guard await isDirectory(url) else {
            throw PersistenceError.notFound(key: url.path)
        }
        do {
            return try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
        } catch {
            throw PersistenceError.storageFailed(
                operation: "contentsOfDirectory(\(url.path))",
                reason: error.localizedDescription
            )
        }
    }

    /// Reads a whole file into memory, holding all of its bytes at once.
    ///
    /// Every failure is reported as ``PersistenceError/storageFailed(operation:reason:)``,
    /// including a file that is not there. It is never reported as
    /// ``PersistenceError/notFound(key:)``, which is what ``InMemoryFileSystem`` throws for the
    /// same case, so code that distinguishes the two must ask ``exists(_:)`` first rather than
    /// matching on the error.
    public func readData(_ url: URL) async throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            throw PersistenceError.storageFailed(
                operation: "readData(\(url.path))",
                reason: error.localizedDescription
            )
        }
    }
}
