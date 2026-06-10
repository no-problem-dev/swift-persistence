import Foundation
import PersistenceCore

/// ``FileSystemReading`` backed by `FileManager`.
///
/// Reads from the real local filesystem. `FileManager.default` is safe for the
/// concurrent read operations used here, so this is a value type rather than an
/// actor.
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
