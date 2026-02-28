import Testing
import Foundation
import PersistenceCore
import PersistenceTesting

// MARK: - Test Helpers

private struct SampleItem: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    var name: String
    var count: Int
}

private struct SampleEntry: Codable, Sendable, Equatable {
    let name: String
    let value: Int
}

// MARK: - InMemoryKeyValueStore Tests

@Suite("InMemoryKeyValueStore")
struct InMemoryKeyValueStoreTests {

    @Test("String round-trip")
    func stringRoundTrip() async throws {
        let store = InMemoryKeyValueStore()
        try await store.setValue("hello", forKey: "key")
        let result = try await store.string(forKey: "key")
        #expect(result == "hello")
    }

    @Test("Bool round-trip")
    func boolRoundTrip() async throws {
        let store = InMemoryKeyValueStore()
        try await store.setValue(true, forKey: "flag")
        let result = try await store.bool(forKey: "flag")
        #expect(result == true)
    }

    @Test("Int round-trip")
    func intRoundTrip() async throws {
        let store = InMemoryKeyValueStore()
        try await store.setValue(42, forKey: "count")
        let result = try await store.int(forKey: "count")
        #expect(result == 42)
    }

    @Test("Codable struct round-trip")
    func codableRoundTrip() async throws {
        let store = InMemoryKeyValueStore()
        let entry = SampleEntry(name: "test", value: 123)
        try await store.setValue(entry, forKey: "entry")
        let result: SampleEntry? = try await store.value(forKey: "entry", type: SampleEntry.self)
        #expect(result == entry)
    }

    @Test("Returns nil for missing key")
    func missingKey() async throws {
        let store = InMemoryKeyValueStore()
        let result = try await store.string(forKey: "nonexistent")
        #expect(result == nil)
    }

    @Test("Overwrite existing value")
    func overwrite() async throws {
        let store = InMemoryKeyValueStore()
        try await store.setValue("first", forKey: "key")
        try await store.setValue("second", forKey: "key")
        #expect(try await store.string(forKey: "key") == "second")
    }

    @Test("Remove value")
    func removeValue() async throws {
        let store = InMemoryKeyValueStore()
        try await store.setValue("hello", forKey: "key")
        await store.removeValue(forKey: "key")
        #expect(try await store.string(forKey: "key") == nil)
        let contains = await store.contains(key: "key")
        #expect(!contains)
    }

    @Test("Contains")
    func contains() async throws {
        let store = InMemoryKeyValueStore()
        var result = await store.contains(key: "key")
        #expect(!result)
        try await store.setValue("hello", forKey: "key")
        result = await store.contains(key: "key")
        #expect(result)
    }
}

// MARK: - InMemorySecureStore Tests

@Suite("InMemorySecureStore")
struct InMemorySecureStoreTests {

    @Test("String round-trip")
    func stringRoundTrip() async throws {
        let store = InMemorySecureStore()
        try await store.setString("api-key-123", forKey: "anthropic")
        let result = try await store.getString(forKey: "anthropic")
        #expect(result == "api-key-123")
    }

    @Test("Data round-trip")
    func dataRoundTrip() async throws {
        let store = InMemorySecureStore()
        let data = Data([0x01, 0x02, 0x03])
        try await store.setData(data, forKey: "blob")
        let result = try await store.getData(forKey: "blob")
        #expect(result == data)
    }

    @Test("Returns nil for missing key")
    func missingKey() async throws {
        let store = InMemorySecureStore()
        let result = try await store.getString(forKey: "nonexistent")
        #expect(result == nil)
    }

    @Test("Overwrite existing value")
    func overwrite() async throws {
        let store = InMemorySecureStore()
        try await store.setString("old-key", forKey: "api")
        try await store.setString("new-key", forKey: "api")
        #expect(try await store.getString(forKey: "api") == "new-key")
    }

    @Test("Remove value")
    func remove() async throws {
        let store = InMemorySecureStore()
        try await store.setString("secret", forKey: "key")
        await store.remove(forKey: "key")
        #expect(try await store.getString(forKey: "key") == nil)
        #expect(try await !store.contains(key: "key"))
    }

    @Test("Contains")
    func contains() async throws {
        let store = InMemorySecureStore()
        #expect(try await !store.contains(key: "key"))
        try await store.setString("value", forKey: "key")
        #expect(try await store.contains(key: "key"))
    }
}

// MARK: - InMemoryDocumentStore Tests

@Suite("InMemoryDocumentStore")
struct InMemoryDocumentStoreTests {

    @Test("Save and load round-trip")
    func saveAndLoad() async throws {
        let store = InMemoryDocumentStore<SampleItem>()
        let item = SampleItem(id: UUID(), name: "test", count: 1)
        try await store.save(item)
        let loaded = try await store.load(id: item.id)
        #expect(loaded == item)
    }

    @Test("LoadAll returns all documents")
    func loadAll() async throws {
        let store = InMemoryDocumentStore<SampleItem>()
        let items = (0..<3).map { SampleItem(id: UUID(), name: "item\($0)", count: $0) }
        for item in items {
            try await store.save(item)
        }
        let loaded = try await store.loadAll()
        #expect(loaded.count == 3)
    }

    @Test("LoadAll returns empty array when empty")
    func loadAllEmpty() async throws {
        let store = InMemoryDocumentStore<SampleItem>()
        let loaded = try await store.loadAll()
        #expect(loaded.isEmpty)
    }

    @Test("Load nonexistent throws notFound")
    func loadNotFound() async throws {
        let store = InMemoryDocumentStore<SampleItem>()
        await #expect(throws: PersistenceError.self) {
            try await store.load(id: UUID())
        }
    }

    @Test("Delete removes document")
    func delete() async throws {
        let store = InMemoryDocumentStore<SampleItem>()
        let item = SampleItem(id: UUID(), name: "test", count: 1)
        try await store.save(item)
        try await store.delete(id: item.id)
        let exists = await store.exists(id: item.id)
        #expect(!exists)
        let count = await store.count
        #expect(count == 0)
    }

    @Test("Delete nonexistent throws notFound")
    func deleteNotFound() async throws {
        let store = InMemoryDocumentStore<SampleItem>()
        await #expect(throws: PersistenceError.self) {
            try await store.delete(id: UUID())
        }
    }

    @Test("Exists")
    func exists() async throws {
        let store = InMemoryDocumentStore<SampleItem>()
        let id = UUID()
        var result = await store.exists(id: id)
        #expect(!result)
        try await store.save(SampleItem(id: id, name: "test", count: 0))
        result = await store.exists(id: id)
        #expect(result)
    }

    @Test("Overwrite existing document")
    func overwrite() async throws {
        let store = InMemoryDocumentStore<SampleItem>()
        let id = UUID()
        try await store.save(SampleItem(id: id, name: "v1", count: 1))
        try await store.save(SampleItem(id: id, name: "v2", count: 2))
        let loaded = try await store.load(id: id)
        #expect(loaded.name == "v2")
        let count = await store.count
        #expect(count == 1)
    }
}

// MARK: - InMemoryRegistryStore Tests

@Suite("InMemoryRegistryStore")
struct InMemoryRegistryStoreTests {

    @Test("Load returns empty dict initially")
    func loadEmpty() async {
        let store = InMemoryRegistryStore<SampleEntry>()
        let registry = await store.load()
        #expect(registry.isEmpty)
    }

    @Test("Save and load round-trip")
    func saveAndLoad() async throws {
        let store = InMemoryRegistryStore<SampleEntry>()
        let registry = [
            "key1": SampleEntry(name: "one", value: 1),
            "key2": SampleEntry(name: "two", value: 2),
        ]
        try await store.save(registry)
        let loaded = await store.load()
        #expect(loaded == registry)
    }

    @Test("Pre-populated initializer")
    func prePopulated() async {
        let initial = ["key": SampleEntry(name: "init", value: 0)]
        let store = InMemoryRegistryStore(initial)
        let loaded = await store.load()
        #expect(loaded == initial)
    }

    @Test("Overwrite replaces entire registry")
    func overwrite() async throws {
        let store = InMemoryRegistryStore<SampleEntry>()
        try await store.save(["a": SampleEntry(name: "a", value: 1)])
        try await store.save(["b": SampleEntry(name: "b", value: 2)])
        let loaded = await store.load()
        #expect(loaded.keys.contains("b"))
        #expect(!loaded.keys.contains("a"))
    }
}

// MARK: - InMemoryKeyResolver Tests

@Suite("InMemoryKeyResolver")
struct InMemoryKeyResolverTests {

    @Test("Resolves known key")
    func resolveKnown() async {
        let resolver = InMemoryKeyResolver(["API_KEY": "sk-123"])
        let result = await resolver.resolve("API_KEY")
        #expect(result == "sk-123")
    }

    @Test("Returns nil for unknown key")
    func resolveUnknown() async {
        let resolver = InMemoryKeyResolver(["API_KEY": "sk-123"])
        let result = await resolver.resolve("OTHER_KEY")
        #expect(result == nil)
    }

    @Test("Empty resolver returns nil")
    func emptyResolver() async {
        let resolver = InMemoryKeyResolver()
        let result = await resolver.resolve("anything")
        #expect(result == nil)
    }
}
