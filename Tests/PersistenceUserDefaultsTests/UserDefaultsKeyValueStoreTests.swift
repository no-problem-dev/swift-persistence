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
    func stringRoundTrip() throws {
        let store = makeStore()
        try store.setValue("hello", forKey: "key")
        #expect(try store.string(forKey: "key") == "hello")
    }

    @Test("Bool round-trip")
    func boolRoundTrip() throws {
        let store = makeStore()
        try store.setValue(true, forKey: "flag")
        #expect(try store.bool(forKey: "flag") == true)
    }

    @Test("Int round-trip")
    func intRoundTrip() throws {
        let store = makeStore()
        try store.setValue(42, forKey: "count")
        #expect(try store.int(forKey: "count") == 42)
    }

    @Test("Double round-trip")
    func doubleRoundTrip() throws {
        let store = makeStore()
        try store.setValue(3.14, forKey: "pi")
        #expect(try store.double(forKey: "pi") == 3.14)
    }

    @Test("Data round-trip")
    func dataRoundTrip() throws {
        let store = makeStore()
        let data = Data([0x01, 0x02, 0x03])
        try store.setValue(data, forKey: "blob")
        #expect(try store.data(forKey: "blob") == data)
    }

    @Test("Codable struct round-trip")
    func codableRoundTrip() throws {
        let store = makeStore()
        let value = CodableStruct(name: "test", value: 123)
        try store.setValue(value, forKey: "entry")
        let result: CodableStruct? = try store.value(forKey: "entry", type: CodableStruct.self)
        #expect(result == value)
    }

    @Test("Returns nil for missing key")
    func missingKey() throws {
        let store = makeStore()
        #expect(try store.string(forKey: "nonexistent") == nil)
    }

    @Test("Overwrite existing value")
    func overwrite() throws {
        let store = makeStore()
        try store.setValue("first", forKey: "key")
        try store.setValue("second", forKey: "key")
        #expect(try store.string(forKey: "key") == "second")
    }

    @Test("Remove value")
    func removeValue() throws {
        let store = makeStore()
        try store.setValue("hello", forKey: "key")
        try store.removeValue(forKey: "key")
        #expect(try store.string(forKey: "key") == nil)
    }

    @Test("Contains returns correct boolean")
    func contains() throws {
        let store = makeStore()
        #expect(!store.contains(key: "key"))
        try store.setValue("value", forKey: "key")
        #expect(store.contains(key: "key"))
    }

    @Test("Bool nil for missing key (not false)")
    func boolNilNotFalse() throws {
        let store = makeStore()
        let result = try store.bool(forKey: "missing")
        #expect(result == nil)
    }
}
