import Foundation
import PersistenceCore

/// ``RegistryStore`` backed by a single JSON file on disk.
///
/// Generalizes the registry pattern where a single JSON file maps
/// string keys to Codable metadata entries. The file is read/written
/// atomically.
///
/// Implemented as an `actor` so that file I/O is automatically moved
/// off the caller's actor (e.g., `@MainActor`) via actor hop.
public actor FileSystemRegistryStore<Entry: Codable & Sendable>: RegistryStore {

    private let registryURL: URL

    /// Creates a file-system registry store from a full file URL.
    ///
    /// - Parameter registryURL: Full path to the JSON registry file.
    public init(registryURL: URL) {
        self.registryURL = registryURL
    }

    /// Creates a file-system registry store from a directory and filename.
    ///
    /// - Parameters:
    ///   - directory: The directory containing the registry file.
    ///   - filename: The registry filename. Defaults to `"registry.json"`.
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
