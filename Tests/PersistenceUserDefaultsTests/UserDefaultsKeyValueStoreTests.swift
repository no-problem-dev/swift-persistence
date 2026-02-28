import Testing
import Foundation
import PersistenceCore
import PersistenceUserDefaults

private struct CodableStruct: Codable, Sendable, Equatable {
    let name: String
    let value: Int
}

@Suite("UserDefaultsKeyValueStore")
struct UserDefaultsKeyValueStoreTests {

    /// Each test uses a unique suite name for isolation.
    private func makeStore() -> UserDefaultsKeyValueStore {
        UserDefaultsKeyValueStore(suiteName: "test.\(UUID().uuidString)")
    }

    @Test("String round-trip")
    func stringRoundTrip() async throws {
        let store = makeStore()
        try await store.setValue("hello", forKey: "key")
        #expect(try await store.string(forKey: "key") == "hello")
    }

    @Test("Bool round-trip")
    func boolRoundTrip() async throws {
        let store = makeStore()
        try await store.setValue(true, forKey: "flag")
        #expect(try await store.bool(forKey: "flag") == true)
    }

    @Test("Int round-trip")
    func intRoundTrip() async throws {
        let store = makeStore()
        try await store.setValue(42, forKey: "count")
        #expect(try await store.int(forKey: "count") == 42)
    }

    @Test("Double round-trip")
    func doubleRoundTrip() async throws {
        let store = makeStore()
        try await store.setValue(3.14, forKey: "pi")
        #expect(try await store.double(forKey: "pi") == 3.14)
    }

    @Test("Data round-trip")
    func dataRoundTrip() async throws {
        let store = makeStore()
        let data = Data([0x01, 0x02, 0x03])
        try await store.setValue(data, forKey: "blob")
        #expect(try await store.data(forKey: "blob") == data)
    }

    @Test("Codable struct round-trip")
    func codableRoundTrip() async throws {
        let store = makeStore()
        let value = CodableStruct(name: "test", value: 123)
        try await store.setValue(value, forKey: "entry")
        let result: CodableStruct? = try await store.value(forKey: "entry", type: CodableStruct.self)
        #expect(result == value)
    }

    @Test("Returns nil for missing key")
    func missingKey() async throws {
        let store = makeStore()
        #expect(try await store.string(forKey: "nonexistent") == nil)
    }

    @Test("Overwrite existing value")
    func overwrite() async throws {
        let store = makeStore()
        try await store.setValue("first", forKey: "key")
        try await store.setValue("second", forKey: "key")
        #expect(try await store.string(forKey: "key") == "second")
    }

    @Test("Remove value")
    func removeValue() async throws {
        let store = makeStore()
        try await store.setValue("hello", forKey: "key")
        await store.removeValue(forKey: "key")
        #expect(try await store.string(forKey: "key") == nil)
    }

    @Test("Contains returns correct boolean")
    func contains() async throws {
        let store = makeStore()
        var result = await store.contains(key: "key")
        #expect(!result)
        try await store.setValue("value", forKey: "key")
        result = await store.contains(key: "key")
        #expect(result)
    }

    @Test("Bool nil for missing key (not false)")
    func boolNilNotFalse() async throws {
        let store = makeStore()
        let result = try await store.bool(forKey: "missing")
        #expect(result == nil)
    }
}
