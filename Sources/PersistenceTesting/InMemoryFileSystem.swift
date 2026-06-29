import Foundation
import PersistenceCore

/// テスト用のインメモリ ``FileSystemReading`` & ``FileSystemWriting``。
///
/// ``addFile(_:string:)`` / ``addFile(_:data:)`` またはライト API でツリーを構築する。
/// 先祖ディレクトリは暗黙的に作成される。
/// ディスクに触れることなく探索・生成ロジックを決定的にテストできる。
public actor InMemoryFileSystem: FileSystemReading, FileSystemWriting {

    private var files: [String: Data] = [:]
    private var directories: Set<String> = []

    public init() {}

    // MARK: - Building the tree

    /// 生バイトのファイルを追加し、全先祖ディレクトリを登録する。
    public func addFile(_ url: URL, data: Data) {
        let path = Self.normalize(url)
        files[path] = data
        registerAncestors(of: path)
    }

    /// UTF-8 文字列からファイルを追加する。
    public func addFile(_ url: URL, string: String) {
        addFile(url, data: Data(string.utf8))
    }

    /// 空ディレクトリを追加し、全先祖ディレクトリを登録する。
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

    // MARK: - FileSystemWriting

    public func createDirectory(_ url: URL) throws {
        addDirectory(url)
    }

    public func write(_ data: Data, to url: URL) throws {
        addFile(url, data: data)
    }

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
