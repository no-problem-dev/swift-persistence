# Getting Started with swift-persistence

Add persistence to your Swift app in a few lines of code.

## Overview

### Installation

Add the package to `Package.swift` with Swift Package Manager:

```swift
dependencies: [
    .package(
        url: "https://github.com/no-problem-dev/swift-persistence.git",
        from: "1.0.0"
    )
]
```

Then add only the modules you need to your target's `dependencies`:

| Module | Use it for |
|--------|-------------|
| `PersistenceCore` | Always — the protocols and `PersistenceError` |
| `PersistenceUserDefaults` | User settings kept in `UserDefaults` |
| `PersistenceKeychain` | API keys, tokens, and credentials |
| `PersistenceFileSystem` | Documents and registries on disk |
| `PersistenceTesting` | In-memory doubles for unit tests |

### The UserDefaults backend — `UserDefaultsKeyValueStore`

Use `UserDefaultsKeyValueStore` for lightweight user settings. Primitive types (`String`, `Bool`, `Int`, `Double`, `Data`) go through the native accessors; every other `Codable` type is JSON-encoded automatically.

```swift
import PersistenceUserDefaults

let store = UserDefaultsKeyValueStore()

// Write
try await store.setValue("dark", forKey: "theme")

// Read through a convenience accessor
let theme: String? = try await store.string(forKey: "theme")

// Custom Codable types
struct AppPreferences: Codable, Sendable {
    var fontSize: Int
    var colorScheme: String
}
try await store.setValue(AppPreferences(fontSize: 14, colorScheme: "dark"), forKey: "prefs")
let prefs: AppPreferences? = try await store.value(forKey: "prefs", type: AppPreferences.self)
```

### The Keychain backend — `KeychainSecureStore`

Use `KeychainSecureStore` for sensitive values such as API keys and session tokens. Items are encrypted by the operating system and stored as `kSecClassGenericPassword`.

```swift
import PersistenceKeychain

// Default: whenUnlockedThisDeviceOnly — device-only, never synced to iCloud
let secrets = KeychainSecureStore(service: Bundle.main.bundleIdentifier ?? "com.example.app")

// Store an API key
try await secrets.setString("sk-live-abc123", forKey: "openai_api_key")

// Read it back
if let apiKey = try await secrets.getString(forKey: "openai_api_key") {
    // Use apiKey
}

// Use .whenUnlocked when the credential has to reach the user's other devices
let sharedSecrets = KeychainSecureStore(
    service: "com.example.app",
    accessibility: .whenUnlocked
)
```

### The file system backend — `FileSystemDocumentStore` and `FoundationFileSystem`

`FileSystemDocumentStore` persists each `Identifiable & Codable` document as its own `{id}.json` file. `FoundationFileSystem` gives you raw file-tree access for walking directories and generating files.

```swift
import Foundation
import PersistenceFileSystem

struct Note: Codable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var body: String
}

// Initialising the store creates the directory if it does not exist
let store = try FileSystemDocumentStore<Note>(
    directory: URL.documentsDirectory.appendingPathComponent("notes")
)

// Create or update
let note = Note(id: UUID(), title: "Meeting notes", body: "...")
try await store.save(note)

// Read
let loaded = try await store.load(id: note.id)
let all: [Note] = try await store.loadAll()

// Delete
try await store.delete(id: note.id)
```

### Testing

Replace every production backend with an in-memory double from `PersistenceTesting` — no disk and no Keychain involved. Import `PersistenceCore` alongside it for the protocol types.

```swift
import PersistenceCore
import PersistenceTesting

// Inject through protocol types — the same code runs against either backend
let store: any KeyValueStore = InMemoryKeyValueStore()
let secrets: any SecureStore = InMemorySecureStore()
let docs: any DocumentStore<Note> = InMemoryDocumentStore<Note>()
let fs: any FileSystemReading & FileSystemWriting = InMemoryFileSystem()

// Seed fixture data for deterministic tests
let seeded = InMemoryKeyValueStore(["theme": "dark"])
let fixedResolver = InMemoryKeyResolver(["API_KEY": "test-key-abc"])
```

### Error handling

Throwing operations fail with ``PersistenceError``. It conforms to `LocalizedError`, so `error.localizedDescription` gives you a readable message naming the key and the cause.

A missing key is not always an error. ``KeyValueStore`` and ``SecureStore`` reads return `nil` when the key is absent, while ``DocumentStore`` and the file system protocols throw ``PersistenceError/notFound(key:)``:

```swift
do {
    let note = try await store.load(id: deletedNoteID)
} catch let error as PersistenceError {
    // error.localizedDescription → "Item not found for key 'E621E1F8-C36C-495A-93FC-0C247A3E6E5F'."
    print(error.localizedDescription)
}
```
