import Foundation

/// Write access to a tree of files and directories, decoupled from the real disk.
///
/// This is the counterpart to ``FileSystemReading``, and both shipped backends conform to the
/// two together, so code that reads and writes a tree can take one value for both.
///
/// Every call stands alone. Nothing here is transactional, so a call that fails after creating a
/// directory leaves that directory behind.
///
/// The methods are `async` so an implementation can keep blocking I/O off the caller's actor.
///
/// Implementations: ``FoundationFileSystem``, ``InMemoryFileSystem``.
public protocol FileSystemWriting: Sendable {

    /// Creates a directory along with any missing parents.
    ///
    /// Calling this on a directory that already exists succeeds and changes nothing, so callers
    /// need not check first.
    ///
    /// - Throws: ``PersistenceError/directoryCreationFailed(path:reason:)``, which is also how a
    ///   file already occupying the URL is reported.
    func createDirectory(_ url: URL) async throws

    /// Replaces the file at this URL with these bytes, creating parent directories as needed.
    ///
    /// The replacement is atomic in that a reader sees either the previous file or the new one,
    /// never a half-written one. It is not durable: the bytes are not flushed, so a power loss
    /// straight after the call can still lose them.
    ///
    /// - Throws: ``PersistenceError/directoryCreationFailed(path:reason:)`` when the parent
    ///   directory cannot be made, ``PersistenceError/storageFailed(operation:reason:)`` when the
    ///   write fails.
    func write(_ data: Data, to url: URL) async throws

    /// Deletes a file, or a directory together with everything inside it.
    ///
    /// Deleting something that is not there succeeds and changes nothing. The call does not
    /// report whether anything was actually removed.
    ///
    /// - Throws: ``PersistenceError/storageFailed(operation:reason:)``.
    func removeItem(_ url: URL) async throws

    /// Moves a file, or a whole directory subtree, to another location.
    ///
    /// Never overwrites: an occupied destination is an error rather than a replacement. Missing
    /// parent directories of the destination are created first.
    ///
    /// - Throws: ``PersistenceError/notFound(key:)`` when the source is missing,
    ///   ``PersistenceError/storageFailed(operation:reason:)`` when the destination is occupied
    ///   or the move fails.
    func moveItem(from source: URL, to destination: URL) async throws
}

extension FileSystemWriting {

    /// Writes text to a file as UTF-8 bytes, replacing it as atomically as the byte overload does.
    public func write(_ string: String, to url: URL) async throws {
        try await write(Data(string.utf8), to: url)
    }
}
