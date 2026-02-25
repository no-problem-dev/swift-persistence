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
    func stringRoundTrip() throws {
        let store = InMemoryKeyValueStore()
        try store.setValue("hello", forKey: "key")
        let result = try store.string(forKey: "key")
        #expect(result == "hello")
    }

    @Test("Bool round-trip")
    func boolRoundTrip() throws {
        let store = InMemoryKeyValueStore()
        try store.setValue(true, forKey: "flag")
        let result = try store.bool(forKey: "flag")
        #expect(result == true)
    }

    @Test("Int round-trip")
    func intRoundTrip() throws {
        let store = InMemoryKeyValueStore()
        try store.setValue(42, forKey: "count")
        let result = try store.int(forKey: "count")
        #expect(result == 42)
    }

    @Test("Codable struct round-trip")
    func codableRoundTrip() throws {
        let store = InMemoryKeyValueStore()
        let entry = SampleEntry(name: "test", value: 123)
        try store.setValue(entry, forKey: "entry")
        let result: SampleEntry? = try store.value(forKey: "entry", type: SampleEntry.self)
        #expect(result == entry)
    }

    @Test("Returns nil for missing key")
    func missingKey() throws {
        let store = InMemoryKeyValueStore()
        let result = try store.string(forKey: "nonexistent")
        #expect(result == nil)
    }

    @Test("Overwrite existing value")
    func overwrite() throws {
        let store = InMemoryKeyValueStore()
        try store.setValue("first", forKey: "key")
        try store.setValue("second", forKey: "key")
        #expect(try store.string(forKey: "key") == "second")
    }

    @Test("Remove value")
    func removeValue() throws {
        let store = InMemoryKeyValueStore()
        try store.setValue("hello", forKey: "key")
        try store.removeValue(forKey: "key")
        #expect(try store.string(forKey: "key") == nil)
        #expect(!store.contains(key: "key"))
    }

    @Test("Contains")
    func contains() throws {
        let store = InMemoryKeyValueStore()
        #expect(!store.contains(key: "key"))
        try store.setValue("hello", forKey: "key")
        #expect(store.contains(key: "key"))
    }
}

// MARK: - InMemorySecureStore Tests

@Suite("InMemorySecureStore")
struct InMemorySecureStoreTests {

    @Test("String round-trip")
    func stringRoundTrip() throws {
        let store = InMemorySecureStore()
        try store.setString("api-key-123", forKey: "anthropic")
        let result = try store.getString(forKey: "anthropic")
        #expect(result == "api-key-123")
    }

    @Test("Data round-trip")
    func dataRoundTrip() throws {
        let store = InMemorySecureStore()
        let data = Data([0x01, 0x02, 0x03])
        try store.setData(data, forKey: "blob")
        let result = try store.getData(forKey: "blob")
        #expect(result == data)
    }

    @Test("Returns nil for missing key")
    func missingKey() throws {
        let store = InMemorySecureStore()
        let result = try store.getString(forKey: "nonexistent")
        #expect(result == nil)
    }

    @Test("Overwrite existing value")
    func overwrite() throws {
        let store = InMemorySecureStore()
        try store.setString("old-key", forKey: "api")
        try store.setString("new-key", forKey: "api")
        #expect(try store.getString(forKey: "api") == "new-key")
    }

    @Test("Remove value")
    func remove() throws {
        let store = InMemorySecureStore()
        try store.setString("secret", forKey: "key")
        try store.remove(forKey: "key")
        #expect(try store.getString(forKey: "key") == nil)
        #expect(try !store.contains(key: "key"))
    }

    @Test("Contains")
    func contains() throws {
        let store = InMemorySecureStore()
        #expect(try !store.contains(key: "key"))
        try store.setString("value", forKey: "key")
        #expect(try store.contains(key: "key"))
    }
}

// MARK: - InMemoryDocumentStore Tests

@Suite("InMemoryDocumentStore")
struct InMemoryDocumentStoreTests {

    @Test("Save and load round-trip")
    func saveAndLoad() throws {
        let store = InMemoryDocumentStore<SampleItem>()
        let item = SampleItem(id: UUID(), name: "test", count: 1)
        try store.save(item)
        let loaded = try store.load(id: item.id)
        #expect(loaded == item)
    }

    @Test("LoadAll returns all documents")
    func loadAll() throws {
        let store = InMemoryDocumentStore<SampleItem>()
        let items = (0..<3).map { SampleItem(id: UUID(), name: "item\($0)", count: $0) }
        for item in items {
            try store.save(item)
        }
        let loaded = try store.loadAll()
        #expect(loaded.count == 3)
    }

    @Test("LoadAll returns empty array when empty")
    func loadAllEmpty() throws {
        let store = InMemoryDocumentStore<SampleItem>()
        let loaded = try store.loadAll()
        #expect(loaded.isEmpty)
    }

    @Test("Load nonexistent throws notFound")
    func loadNotFound() throws {
        let store = InMemoryDocumentStore<SampleItem>()
        #expect(throws: PersistenceError.self) {
            try store.load(id: UUID())
        }
    }

    @Test("Delete removes document")
    func delete() throws {
        let store = InMemoryDocumentStore<SampleItem>()
        let item = SampleItem(id: UUID(), name: "test", count: 1)
        try store.save(item)
        try store.delete(id: item.id)
        #expect(!store.exists(id: item.id))
        #expect(store.count == 0)
    }

    @Test("Delete nonexistent throws notFound")
    func deleteNotFound() throws {
        let store = InMemoryDocumentStore<SampleItem>()
        #expect(throws: PersistenceError.self) {
            try store.delete(id: UUID())
        }
    }

    @Test("Exists")
    func exists() throws {
        let store = InMemoryDocumentStore<SampleItem>()
        let id = UUID()
        #expect(!store.exists(id: id))
        try store.save(SampleItem(id: id, name: "test", count: 0))
        #expect(store.exists(id: id))
    }

    @Test("Overwrite existing document")
    func overwrite() throws {
        let store = InMemoryDocumentStore<SampleItem>()
        let id = UUID()
        try store.save(SampleItem(id: id, name: "v1", count: 1))
        try store.save(SampleItem(id: id, name: "v2", count: 2))
        let loaded = try store.load(id: id)
        #expect(loaded.name == "v2")
        #expect(store.count == 1)
    }
}

// MARK: - InMemoryRegistryStore Tests

@Suite("InMemoryRegistryStore")
struct InMemoryRegistryStoreTests {

    @Test("Load returns empty dict initially")
    func loadEmpty() {
        let store = InMemoryRegistryStore<SampleEntry>()
        let registry = store.load()
        #expect(registry.isEmpty)
    }

    @Test("Save and load round-trip")
    func saveAndLoad() throws {
        let store = InMemoryRegistryStore<SampleEntry>()
        let registry = [
            "key1": SampleEntry(name: "one", value: 1),
            "key2": SampleEntry(name: "two", value: 2),
        ]
        try store.save(registry)
        let loaded = store.load()
        #expect(loaded == registry)
    }

    @Test("Pre-populated initializer")
    func prePopulated() {
        let initial = ["key": SampleEntry(name: "init", value: 0)]
        let store = InMemoryRegistryStore(initial)
        let loaded = store.load()
        #expect(loaded == initial)
    }

    @Test("Overwrite replaces entire registry")
    func overwrite() throws {
        let store = InMemoryRegistryStore<SampleEntry>()
        try store.save(["a": SampleEntry(name: "a", value: 1)])
        try store.save(["b": SampleEntry(name: "b", value: 2)])
        let loaded = store.load()
        #expect(loaded.keys.contains("b"))
        #expect(!loaded.keys.contains("a"))
    }
}

// MARK: - InMemoryKeyResolver Tests

@Suite("InMemoryKeyResolver")
struct InMemoryKeyResolverTests {

    @Test("Resolves known key")
    func resolveKnown() {
        let resolver = InMemoryKeyResolver(["API_KEY": "sk-123"])
        #expect(resolver.resolve("API_KEY") == "sk-123")
    }

    @Test("Returns nil for unknown key")
    func resolveUnknown() {
        let resolver = InMemoryKeyResolver(["API_KEY": "sk-123"])
        #expect(resolver.resolve("OTHER_KEY") == nil)
    }

    @Test("Empty resolver returns nil")
    func emptyResolver() {
        let resolver = InMemoryKeyResolver()
        #expect(resolver.resolve("anything") == nil)
    }
}
