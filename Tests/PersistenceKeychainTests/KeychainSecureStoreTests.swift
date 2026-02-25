import Testing
import Foundation
import PersistenceCore
import PersistenceKeychain

/// Keychain tests require a real app context (simulator or device).
/// These tests verify the API contract; they may be skipped in CI
/// if Keychain access is unavailable.
@Suite("KeychainSecureStore")
struct KeychainSecureStoreTests {

    /// Uses a unique service name per test for isolation.
    private func makeStore() -> KeychainSecureStore {
        KeychainSecureStore(service: "test.persistence.\(UUID().uuidString)")
    }

    @Test("String set and get round-trip")
    func stringRoundTrip() throws {
        let store = makeStore()
        let key = "api_key_\(UUID().uuidString)"
        try store.setString("sk-test-123", forKey: key)
        let result = try store.getString(forKey: key)
        #expect(result == "sk-test-123")
        // Cleanup
        try store.remove(forKey: key)
    }

    @Test("Data set and get round-trip")
    func dataRoundTrip() throws {
        let store = makeStore()
        let key = "data_\(UUID().uuidString)"
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        try store.setData(data, forKey: key)
        let result = try store.getData(forKey: key)
        #expect(result == data)
        try store.remove(forKey: key)
    }

    @Test("Returns nil for missing key")
    func missingKey() throws {
        let store = makeStore()
        let result = try store.getString(forKey: "nonexistent_\(UUID().uuidString)")
        #expect(result == nil)
    }

    @Test("Overwrite existing value")
    func overwrite() throws {
        let store = makeStore()
        let key = "overwrite_\(UUID().uuidString)"
        try store.setString("old", forKey: key)
        try store.setString("new", forKey: key)
        #expect(try store.getString(forKey: key) == "new")
        try store.remove(forKey: key)
    }

    @Test("Remove deletes value")
    func remove() throws {
        let store = makeStore()
        let key = "remove_\(UUID().uuidString)"
        try store.setString("secret", forKey: key)
        try store.remove(forKey: key)
        #expect(try store.getString(forKey: key) == nil)
    }

    @Test("Remove nonexistent does not throw")
    func removeNonexistent() throws {
        let store = makeStore()
        try store.remove(forKey: "nonexistent_\(UUID().uuidString)")
    }

    @Test("Contains returns correct boolean")
    func contains() throws {
        let store = makeStore()
        let key = "contains_\(UUID().uuidString)"
        #expect(try !store.contains(key: key))
        try store.setString("value", forKey: key)
        #expect(try store.contains(key: key))
        try store.remove(forKey: key)
    }
}
