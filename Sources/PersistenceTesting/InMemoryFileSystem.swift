import Foundation
import PersistenceCore

/// In-memory ``FileSystemReading`` for testing.
///
/// Build a tree with ``addFile(_:string:)`` / ``addFile(_:data:)``; ancestor
/// directories are created implicitly. Lets discovery logic be tested
/// deterministically without touching disk.
public actor InMemoryFileSystem: FileSystemReading {

    private var files: [String: Data] = [:]
    private var directories: Set<String> = []

    public init() {}

    // MARK: - Building the tree

    /// Adds a file with raw bytes, registering all ancestor directories.
    public func addFile(_ url: URL, data: Data) {
        let path = Self.normalize(url)
        files[path] = data
        registerAncestors(of: path)
    }

    /// Adds a file from a UTF-8 string.
    public func addFile(_ url: URL, string: String) {
        addFile(url, data: Data(string.utf8))
    }

    /// Adds an empty directory, registering all ancestor directories.
    public func addDirectory(_ url: URL) {
        let path = Self.normalize(url)
        directories.insert(path)
        registerAncestors(of: path)
    }

    private func registerAncestors(of path: String) {
        var current = (path as NSString).deletingLastPathComponent
        while !current.isEmpty, current != "/", !directories.contains(current) {
            directories.insert(current)
            current = (current as NSString).deletingLastPathComponent
        }
        if current == "/" { directories.insert("/") }
    }

    // MARK: - FileSystemReading

    public func exists(_ url: URL) -> Bool {
        let path = Self.normalize(url)
        return files[path] != nil || directories.contains(path)
    }

    public func isDirectory(_ url: URL) -> Bool {
        directories.contains(Self.normalize(url))
    }

    public func contentsOfDirectory(_ url: URL) throws -> [URL] {
        let dir = Self.normalize(url)
        guard directories.contains(dir) else {
            throw PersistenceError.notFound(key: url.path)
        }
        var children: Set<String> = []
        for path in files.keys where (path as NSString).deletingLastPathComponent == dir {
            children.insert(path)
        }
        for path in directories where path != dir && (path as NSString).deletingLastPathComponent == dir {
            children.insert(path)
        }
        return children.sorted().map { URL(fileURLWithPath: $0) }
    }

    public func readData(_ url: URL) throws -> Data {
        guard let data = files[Self.normalize(url)] else {
            throw PersistenceError.notFound(key: url.path)
        }
        return data
    }

    // MARK: - Helpers

    private static func normalize(_ url: URL) -> String {
        let path = url.standardizedFileURL.path
        if path.count > 1 && path.hasSuffix("/") {
            return String(path.dropLast())
        }
        return path
    }
}
