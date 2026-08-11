import Foundation
import PersistenceCore

/// A file tree held in memory, for use in tests.
///
/// Build the tree with ``addFile(_:string:)``, ``addFile(_:data:)`` and ``addDirectory(_:)``, or
/// just write into it. Either way the ancestor directories appear on their own, so there is never
/// a parent to create first.
///
/// Nothing survives the process. Paths are standardised before use, which resolves `..` and drops
/// a trailing slash, but nothing else about a real file system is modelled: no permissions, no
/// symlinks, no case-insensitive matching, no file sizes. Anything not documented as failing
/// succeeds.
///
/// Directory listings come back sorted, which the disk-backed implementation does not promise, so
/// a test that leans on the order passes here and can still fail against a real disk. Reading a
/// missing file throws ``PersistenceError/notFound(key:)`` here and
/// ``PersistenceError/storageFailed(operation:reason:)`` there.
///
/// Being an actor, it is safe to share between tasks.
public actor InMemoryFileSystem: FileSystemReading, FileSystemWriting {

    private var files: [String: Data] = [:]
    private var directories: Set<String> = []

    public init() {}

    // MARK: - Building the tree

    /// Puts a file at this URL, replacing any file already there and creating its ancestors.
    public func addFile(_ url: URL, data: Data) {
        let path = Self.normalize(url)
        files[path] = data
        registerAncestors(of: path)
    }

    /// Puts a file at this URL holding the UTF-8 bytes of a string.
    public func addFile(_ url: URL, string: String) {
        addFile(url, data: Data(string.utf8))
    }

    /// Creates an empty directory along with its ancestors.
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

    /// Lists the immediate children of a directory, sorted by path.
    ///
    /// The sort is this implementation's own convenience and not part of the protocol, so tests
    /// that rely on it will not carry over to the disk-backed tree.
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

    // MARK: - FileSystemWriting

    public func createDirectory(_ url: URL) throws {
        addDirectory(url)
    }

    public func write(_ data: Data, to url: URL) throws {
        addFile(url, data: data)
    }

    /// Removes the path and everything beneath it, and never throws.
    ///
    /// A path that holds nothing is left alone, and the call reports nothing either way.
    public func removeItem(_ url: URL) throws {
        let path = Self.normalize(url)
        let prefix = path + "/"
        files = files.filter { $0.key != path && !$0.key.hasPrefix(prefix) }
        directories = directories.filter { $0 != path && !$0.hasPrefix(prefix) }
    }

    public func moveItem(from source: URL, to destination: URL) throws {
        let src = Self.normalize(source)
        let dst = Self.normalize(destination)
        guard files[src] != nil || directories.contains(src) else {
            throw PersistenceError.notFound(key: source.path)
        }
        guard files[dst] == nil && !directories.contains(dst) else {
            throw PersistenceError.storageFailed(
                operation: "moveItem(\(source.path) -> \(destination.path))",
                reason: "Destination already exists"
            )
        }
        let srcPrefix = src + "/"
        let dstPrefix = dst + "/"
        func rebase(_ p: String) -> String {
            p == src ? dst : dstPrefix + String(p.dropFirst(srcPrefix.count))
        }
        let movedFiles = files.filter { $0.key == src || $0.key.hasPrefix(srcPrefix) }
        let movedDirs = directories.filter { $0 == src || $0.hasPrefix(srcPrefix) }
        for (p, d) in movedFiles {
            files[p] = nil
            files[rebase(p)] = d
        }
        for p in movedDirs {
            directories.remove(p)
            directories.insert(rebase(p))
        }
        registerAncestors(of: dst)
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
