import Foundation

/// Read-only filesystem traversal abstraction.
///
/// Generalizes the directory-walking and file-reading needed by consumers that
/// scan a tree for files (e.g. discovering `SKILL.md` files under skill roots),
/// without binding them to `FileManager`. This keeps such consumers testable
/// against an in-memory tree and swappable for sandboxed or remote backends.
///
/// Unlike ``DocumentStore`` (keyed CRUD) and ``RegistryStore`` (single keyed
/// file), this models raw tree traversal: existence, directory listing, and
/// byte reads.
///
/// All methods are `async` so file-backed implementations can move I/O off the
/// caller's actor.
///
/// Implementations: ``FoundationFileSystem``, ``InMemoryFileSystem``.
public protocol FileSystemReading: Sendable {

    /// Returns `true` if a file or directory exists at `url`.
    func exists(_ url: URL) async -> Bool

    /// Returns `true` if a directory exists at `url`.
    func isDirectory(_ url: URL) async -> Bool

    /// Returns the immediate children (files and directories) of `url`.
    ///
    /// - Throws: ``PersistenceError/notFound(key:)`` if `url` is not an existing
    ///   directory, or ``PersistenceError/storageFailed(operation:reason:)`` on
    ///   an underlying read error.
    func contentsOfDirectory(_ url: URL) async throws -> [URL]

    /// Reads the raw bytes of the file at `url`.
    ///
    /// - Throws: ``PersistenceError/notFound(key:)`` if no file exists, or
    ///   ``PersistenceError/storageFailed(operation:reason:)`` on a read error.
    func readData(_ url: URL) async throws -> Data
}

extension FileSystemReading {

    /// Reads the file at `url` as a UTF-8 string.
    public func readString(_ url: URL) async throws -> String {
        let data = try await readData(url)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.decodingFailed(
                key: url.path,
                reason: "File is not valid UTF-8"
            )
        }
        return string
    }
}
