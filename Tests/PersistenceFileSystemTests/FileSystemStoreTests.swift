import Testing
import Foundation
import PersistenceCore
import PersistenceFileSystem

// MARK: - Test Helpers

private struct TestDocument: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    var title: String
    var createdAt: Date

    static func sample(title: String = "Test") -> TestDocument {
        TestDocument(id: UUID(), title: title, createdAt: Date())
    }
}

private struct TestEntry: Codable, Sendable, Equatable {
    let name: String
    let size: Int64
}

private func makeTempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("PersistenceTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func removeTempDir(_ dir: URL) {
    try? FileManager.default.removeItem(at: dir)
}

// MARK: - FileSystemDocumentStore Tests

@Suite("FileSystemDocumentStore")
struct FileSystemDocumentStoreTests {

    @Test("Save and load round-trip")
    func saveAndLoad() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let doc = TestDocument.sample(title: "Hello")
        try await store.save(doc)
        let loaded = try await store.load(id: doc.id)
        #expect(loaded.id == doc.id)
        #expect(loaded.title == doc.title)
    }

    @Test("LoadAll returns all documents")
    func loadAll() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let docs = (0..<3).map { TestDocument.sample(title: "Doc \($0)") }
        for doc in docs {
            try await store.save(doc)
        }
        let loaded = try await store.loadAll()
        #expect(loaded.count == 3)
    }

    @Test("LoadAll returns empty array for empty directory")
    func loadAllEmpty() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let loaded = try await store.loadAll()
        #expect(loaded.isEmpty)
    }

    @Test("Load nonexistent throws notFound")
    func loadNotFound() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        await #expect(throws: PersistenceError.self) {
            try await store.load(id: UUID())
        }
    }

    @Test("Delete removes file")
    func delete() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let doc = TestDocument.sample()
        try await store.save(doc)
        try await store.delete(id: doc.id)
        let exists = await store.exists(id: doc.id)
        #expect(!exists)
    }

    @Test("Delete nonexistent throws notFound")
    func deleteNotFound() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        await #expect(throws: PersistenceError.self) {
            try await store.delete(id: UUID())
        }
    }

    @Test("Exists returns correct boolean")
    func exists() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let id = UUID()
        var result = await store.exists(id: id)
        #expect(!result)
        try await store.save(TestDocument(id: id, title: "t", createdAt: Date()))
        result = await store.exists(id: id)
        #expect(result)
    }

    @Test("Overwrite replaces document")
    func overwrite() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let id = UUID()
        try await store.save(TestDocument(id: id, title: "v1", createdAt: Date()))
        try await store.save(TestDocument(id: id, title: "v2", createdAt: Date()))
        let loaded = try await store.load(id: id)
        #expect(loaded.title == "v2")
    }

    @Test("Data persists across store instances")
    func persistsAcrossInstances() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store1 = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let doc = TestDocument.sample(title: "Persistent")
        try await store1.save(doc)

        let store2 = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let loaded = try await store2.load(id: doc.id)
        #expect(loaded.title == "Persistent")
    }
}

// MARK: - FileSystemRegistryStore Tests

@Suite("FileSystemRegistryStore")
struct FileSystemRegistryStoreTests {

    @Test("Load returns empty dict when file is missing")
    func loadEmpty() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = FileSystemRegistryStore<TestEntry>(directory: dir)
        let registry = try await store.load()
        #expect(registry.isEmpty)
    }

    @Test("Save and load round-trip")
    func saveAndLoad() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = FileSystemRegistryStore<TestEntry>(directory: dir)
        let registry = [
            "model-a": TestEntry(name: "Model A", size: 1024),
            "model-b": TestEntry(name: "Model B", size: 2048),
        ]
        try await store.save(registry)
        let loaded = try await store.load()
        #expect(loaded == registry)
    }

    @Test("Save creates directory and file")
    func createsDirectory() async throws {
        let dir = try makeTempDir()
        let subDir = dir.appendingPathComponent("nested/deep")
        defer { removeTempDir(dir) }

        let store = FileSystemRegistryStore<TestEntry>(directory: subDir)
        try await store.save(["key": TestEntry(name: "test", size: 0)])

        let registryPath = subDir.appendingPathComponent("registry.json")
        #expect(FileManager.default.fileExists(atPath: registryPath.path))
    }

    @Test("Custom filename")
    func customFilename() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = FileSystemRegistryStore<TestEntry>(
            directory: dir,
            filename: "adapter-registry.json"
        )
        try await store.save(["key": TestEntry(name: "test", size: 0)])

        let registryPath = dir.appendingPathComponent("adapter-registry.json")
        #expect(FileManager.default.fileExists(atPath: registryPath.path))
    }

    @Test("Data persists across store instances")
    func persistsAcrossInstances() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store1 = FileSystemRegistryStore<TestEntry>(directory: dir)
        try await store1.save(["key": TestEntry(name: "persistent", size: 42)])

        let store2 = FileSystemRegistryStore<TestEntry>(directory: dir)
        let loaded = try await store2.load()
        #expect(loaded["key"]?.name == "persistent")
    }

    @Test("Overwrite replaces entire registry")
    func overwrite() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = FileSystemRegistryStore<TestEntry>(directory: dir)
        try await store.save(["a": TestEntry(name: "a", size: 1)])
        try await store.save(["b": TestEntry(name: "b", size: 2)])
        let loaded = try await store.load()
        #expect(loaded.keys.contains("b"))
        #expect(!loaded.keys.contains("a"))
    }

    // MARK: - Nothing stored yet vs. cannot be read

    /// The schema change, which is the ordinary way to reach this. The bytes are still perfectly
    /// good JSON and still hold everything the entries were made of; they just no longer fit
    /// `Entry`. Answering that with "the registry is empty" is a lie the caller cannot detect.
    @Test("Entry の形が変わったファイルは decodingFailed で落ちる（空とは言わない）")
    func mismatchedSchemaThrows() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let registryURL = dir.appendingPathComponent("registry.json")
        try Data(#"{"model-a":{"name":"Model A","sizeInBytes":1024}}"#.utf8)
            .write(to: registryURL)

        let store = FileSystemRegistryStore<TestEntry>(directory: dir)
        await #expect(throws: PersistenceError.self) {
            try await store.load()
        }
    }

    @Test("壊れた JSON は decodingFailed で落ちる")
    func truncatedJSONThrows() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let registryURL = dir.appendingPathComponent("registry.json")
        try Data(#"{"model-a":{"name":"Model A","#.utf8).write(to: registryURL)

        let store = FileSystemRegistryStore<TestEntry>(directory: dir)
        let error = await #expect(throws: PersistenceError.self) {
            try await store.load()
        }
        guard case .decodingFailed(let key, _) = error else {
            Issue.record("expected decodingFailed, got \(String(describing: error))")
            return
        }
        #expect(key == "registry")
    }

    /// Something is at the path but no bytes can come out of it — a different failure from bytes
    /// that come out and do not fit, and it has its own case.
    @Test("そもそも読めないパスは storageFailed で落ちる")
    func unreadablePathThrows() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        // A directory where the file should be: it exists, and reading it as a file cannot work.
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("registry.json"),
            withIntermediateDirectories: true
        )

        let store = FileSystemRegistryStore<TestEntry>(directory: dir)
        let error = await #expect(throws: PersistenceError.self) {
            try await store.load()
        }
        guard case .storageFailed(let operation, _) = error else {
            Issue.record("expected storageFailed, got \(String(describing: error))")
            return
        }
        #expect(operation == "load")
    }

    /// The reason the load throws at all: the usual cycle is read, change, write back, and a read
    /// that answered "empty" would make the write destroy a file that could still have been
    /// recovered by hand. The throw has to stop the cycle before the save.
    @Test("読めなかった registry は、その後の save で上書きされない")
    func failedLoadNeverLeadsToOverwrite() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let registryURL = dir.appendingPathComponent("registry.json")
        let original = Data(#"{"model-a":{"name":"Model A","sizeInBytes":1024}}"#.utf8)
        try original.write(to: registryURL)

        let store = FileSystemRegistryStore<TestEntry>(directory: dir)

        // Read, change, write back — exactly as a consumer holds a registry.
        var reachedSave = false
        do {
            var entries = try await store.load()
            entries["model-b"] = TestEntry(name: "Model B", size: 2048)
            reachedSave = true
            try await store.save(entries)
        } catch {
            // Expected: the load refuses, so the save is never reached.
        }

        #expect(!reachedSave)
        #expect(try Data(contentsOf: registryURL) == original)
    }

    @Test("一度も書かれていない registry だけが空として読める")
    func onlyAnUnwrittenRegistryReadsAsEmpty() async throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = FileSystemRegistryStore<TestEntry>(directory: dir)
        #expect(try await store.load().isEmpty)

        // And an empty registry that really was written still reads as empty, so "empty" keeps
        // its own meaning rather than becoming a synonym for "no file".
        try await store.save([:])
        #expect(try await store.load().isEmpty)
    }
}
