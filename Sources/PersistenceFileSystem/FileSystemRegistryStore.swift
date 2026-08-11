import Foundation
import PersistenceCore

/// Keeps a whole registry in one JSON file, rewritten in full on every save.
///
/// A save replaces the file with exactly the dictionary it is given, so entries the caller
/// dropped are gone from disk. Nothing is cached, so every read parses the file again.
///
/// A registry that cannot be read comes back empty. A missing file, truncated JSON and an entry
/// that no longer matches `Entry` are all reported the same way, without an error and without a
/// log line, so a schema change silently empties the registry and the next save overwrites the
/// file that could have been recovered by hand. Keep a copy before changing `Entry` if the
/// contents matter.
///
/// The file is written atomically, so a reader sees either the previous registry or the new one.
/// It is not flushed, so a power loss just after a save can still lose it. Keys are sorted in the
/// output, which keeps successive saves diffable.
///
/// Being an actor, calls are serialised and the synchronous file I/O runs on the store's own
/// executor rather than the caller's.
public actor FileSystemRegistryStore<Entry: Codable & Sendable>: RegistryStore {

    private let registryURL: URL

    /// Creates a store over one registry file, without touching the disk yet.
    ///
    /// Neither the file nor its directory is created here. The directory appears on the first
    /// successful save, so an unwritable path only shows up then.
    ///
    /// - Parameter registryURL: Full path of the JSON file, file name included.
    public init(registryURL: URL) {
        self.registryURL = registryURL
    }

    /// Creates a store over a registry file inside a directory, without touching the disk yet.
    ///
    /// - Parameters:
    ///   - directory: Directory holding the file. Created on the first successful save, not now.
    ///   - filename: Name of the file within that directory.
    public init(directory: URL, filename: String = "registry.json") {
        self.registryURL = directory.appendingPathComponent(filename)
    }

    // MARK: - RegistryStore

    public func load() -> [String: Entry] {
        guard FileManager.default.fileExists(atPath: registryURL.path) else {
            return [:]
        }
        do {
            let data = try Data(contentsOf: registryURL)
            return try JSONDecoder().decode([String: Entry].self, from: data)
        } catch {
            return [:]
        }
    }

    public func save(_ registry: [String: Entry]) throws {
        let directory = registryURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw PersistenceError.directoryCreationFailed(
                path: directory.path,
                reason: error.localizedDescription
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(registry)
        } catch {
            throw PersistenceError.encodingFailed(
                key: "registry",
                reason: error.localizedDescription
            )
        }
        do {
            try data.write(to: registryURL, options: .atomic)
        } catch {
            throw PersistenceError.storageFailed(
                operation: "save",
                reason: error.localizedDescription
            )
        }
    }
}
