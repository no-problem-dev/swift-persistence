import Foundation
import PersistenceCore

/// `FileManager` をバックエンドとする ``FileSystemReading`` 実装。
///
/// 実際のローカルファイルシステムを参照する。`FileManager.default` は
/// ここで使用する並行読み取り操作に対してスレッドセーフなので、
/// アクターではなく値型として実装する。
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
