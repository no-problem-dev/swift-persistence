import Foundation

/// Write-side filesystem abstraction — the mirror of ``FileSystemReading``.
///
/// Generalizes the directory creation, file writing, deletion, and renaming
/// needed by consumers that author a tree of files (e.g. writing a user-created
/// `SKILL.md` under a skill root), without binding them to `FileManager`. This
/// keeps such authoring logic testable against an in-memory tree and swappable
/// for sandboxed or remote backends.
///
/// Paired with ``FileSystemReading`` so a single backend (``FoundationFileSystem``
/// on disk, ``InMemoryFileSystem`` in tests) can serve both read and write.
///
/// All methods are `async` so file-backed implementations can move I/O off the
/// caller's actor.
///
/// Implementations: ``FoundationFileSystem``, ``InMemoryFileSystem``.
public protocol FileSystemWriting: Sendable {

    /// Creates the directory at `url`, including any missing intermediate
    /// directories.
    ///
    /// Idempotent: succeeds without error if the directory already exists.
    ///
    /// - Throws: ``PersistenceError/directoryCreationFailed(path:reason:)`` if
    ///   the directory could not be created.
    func createDirectory(_ url: URL) async throws

    /// Writes `data` to the file at `url`, atomically, overwriting any existing
    /// file.
    ///
    /// Ensures the parent directory exists first (creating intermediates as
    /// needed), so a single `write` is sufficient to materialize a file at a
    /// fresh path.
    ///
    /// - Throws: ``PersistenceError/storageFailed(operation:reason:)`` on a
    ///   write error.
    func write(_ data: Data, to url: URL) async throws

    /// Removes the file or directory at `url`, recursively for directories.
    ///
    /// Idempotent: succeeds without error if nothing exists at `url`.
    ///
    /// - Throws: ``PersistenceError/storageFailed(operation:reason:)`` on a
    ///   removal error.
    func removeItem(_ url: URL) async throws

    /// Moves the file or directory at `source` to `destination`, preserving the
    /// subtree.
    ///
    /// - Throws: ``PersistenceError/notFound(key:)`` if `source` does not exist,
    ///   or ``PersistenceError/storageFailed(operation:reason:)`` if
    ///   `destination` already exists or the move fails.
    func moveItem(from source: URL, to destination: URL) async throws
}

extension FileSystemWriting {

    /// Writes `string` as UTF-8 to the file at `url`.
    public func write(_ string: String, to url: URL) async throws {
        try await write(Data(string.utf8), to: url)
    }
}
