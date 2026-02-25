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
    func saveAndLoad() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let doc = TestDocument.sample(title: "Hello")
        try store.save(doc)
        let loaded = try store.load(id: doc.id)
        #expect(loaded.id == doc.id)
        #expect(loaded.title == doc.title)
    }

    @Test("LoadAll returns all documents")
    func loadAll() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let docs = (0..<3).map { TestDocument.sample(title: "Doc \($0)") }
        for doc in docs {
            try store.save(doc)
        }
        let loaded = try store.loadAll()
        #expect(loaded.count == 3)
    }

    @Test("LoadAll returns empty array for empty directory")
    func loadAllEmpty() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let loaded = try store.loadAll()
        #expect(loaded.isEmpty)
    }

    @Test("Load nonexistent throws notFound")
    func loadNotFound() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        #expect(throws: PersistenceError.self) {
            try store.load(id: UUID())
        }
    }

    @Test("Delete removes file")
    func delete() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let doc = TestDocument.sample()
        try store.save(doc)
        try store.delete(id: doc.id)
        #expect(!store.exists(id: doc.id))
    }

    @Test("Delete nonexistent throws notFound")
    func deleteNotFound() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        #expect(throws: PersistenceError.self) {
            try store.delete(id: UUID())
        }
    }

    @Test("Exists returns correct boolean")
    func exists() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let id = UUID()
        #expect(!store.exists(id: id))
        try store.save(TestDocument(id: id, title: "t", createdAt: Date()))
        #expect(store.exists(id: id))
    }

    @Test("Overwrite replaces document")
    func overwrite() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let id = UUID()
        try store.save(TestDocument(id: id, title: "v1", createdAt: Date()))
        try store.save(TestDocument(id: id, title: "v2", createdAt: Date()))
        let loaded = try store.load(id: id)
        #expect(loaded.title == "v2")
    }

    @Test("Data persists across store instances")
    func persistsAcrossInstances() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store1 = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let doc = TestDocument.sample(title: "Persistent")
        try store1.save(doc)

        let store2 = try FileSystemDocumentStore<TestDocument>(directory: dir)
        let loaded = try store2.load(id: doc.id)
        #expect(loaded.title == "Persistent")
    }
}

// MARK: - FileSystemRegistryStore Tests

@Suite("FileSystemRegistryStore")
struct FileSystemRegistryStoreTests {

    @Test("Load returns empty dict when file is missing")
    func loadEmpty() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = FileSystemRegistryStore<TestEntry>(directory: dir)
        let registry = store.load()
        #expect(registry.isEmpty)
    }

    @Test("Save and load round-trip")
    func saveAndLoad() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = FileSystemRegistryStore<TestEntry>(directory: dir)
        let registry = [
            "model-a": TestEntry(name: "Model A", size: 1024),
            "model-b": TestEntry(name: "Model B", size: 2048),
        ]
        try store.save(registry)
        let loaded = store.load()
        #expect(loaded == registry)
    }

    @Test("Save creates directory and file")
    func createsDirectory() throws {
        let dir = try makeTempDir()
        let subDir = dir.appendingPathComponent("nested/deep")
        defer { removeTempDir(dir) }

        let store = FileSystemRegistryStore<TestEntry>(directory: subDir)
        try store.save(["key": TestEntry(name: "test", size: 0)])

        let registryPath = subDir.appendingPathComponent("registry.json")
        #expect(FileManager.default.fileExists(atPath: registryPath.path))
    }

    @Test("Custom filename")
    func customFilename() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = FileSystemRegistryStore<TestEntry>(
            directory: dir,
            filename: "adapter-registry.json"
        )
        try store.save(["key": TestEntry(name: "test", size: 0)])

        let registryPath = dir.appendingPathComponent("adapter-registry.json")
        #expect(FileManager.default.fileExists(atPath: registryPath.path))
    }

    @Test("Data persists across store instances")
    func persistsAcrossInstances() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store1 = FileSystemRegistryStore<TestEntry>(directory: dir)
        try store1.save(["key": TestEntry(name: "persistent", size: 42)])

        let store2 = FileSystemRegistryStore<TestEntry>(directory: dir)
        let loaded = store2.load()
        #expect(loaded["key"]?.name == "persistent")
    }

    @Test("Overwrite replaces entire registry")
    func overwrite() throws {
        let dir = try makeTempDir()
        defer { removeTempDir(dir) }

        let store = FileSystemRegistryStore<TestEntry>(directory: dir)
        try store.save(["a": TestEntry(name: "a", size: 1)])
        try store.save(["b": TestEntry(name: "b", size: 2)])
        let loaded = store.load()
        #expect(loaded.keys.contains("b"))
        #expect(!loaded.keys.contains("a"))
    }
}
