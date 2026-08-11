import Foundation

/// Read-only access to a tree of files and directories, decoupled from the real disk.
///
/// Code that walks a directory tree takes this instead of reaching for `FileManager`, which lets
/// a test hand it a tree built in memory and lets a sandboxed or remote backend stand in the same
/// place.
///
/// Where ``DocumentStore`` and ``RegistryStore`` address records by key, this models traversal:
/// asking what is there, listing a directory, and reading bytes.
///
/// The methods are `async` so an implementation can keep blocking I/O off the caller's actor.
/// Neither shipped implementation suspends once entered, so a call holds its executor until the
/// read finishes.
///
/// Implementations: ``FoundationFileSystem``, ``InMemoryFileSystem``.
public protocol FileSystemReading: Sendable {

    /// Reports whether anything is at this URL, file or directory alike.
    func exists(_ url: URL) async -> Bool

    /// Reports whether this URL is a directory, as opposed to a file or nothing at all.
    func isDirectory(_ url: URL) async -> Bool

    /// Lists the immediate children of a directory, without descending into them.
    ///
    /// - Throws: ``PersistenceError/notFound(key:)`` when the URL is not an existing directory,
    ///   ``PersistenceError/storageFailed(operation:reason:)`` when the listing itself fails.
    ///   The order of the result is not defined.
    func contentsOfDirectory(_ url: URL) async throws -> [URL]

    /// Reads a whole file into memory as raw bytes.
    ///
    /// The implementations disagree about a file that is not there: the in-memory tree throws
    /// ``PersistenceError/notFound(key:)``, while the disk-backed one reports every failure,
    /// missing file included, as ``PersistenceError/storageFailed(operation:reason:)``. Ask
    /// ``exists(_:)`` first rather than matching on the error.
    func readData(_ url: URL) async throws -> Data
}

extension FileSystemReading {

    /// Reads a whole file and decodes it as UTF-8 text.
    ///
    /// - Throws: ``PersistenceError/decodingFailed(key:reason:)`` when the bytes are not valid
    ///   UTF-8, on top of whatever ``readData(_:)`` throws. There is no lossy fallback: one bad
    ///   byte fails the whole file.
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
