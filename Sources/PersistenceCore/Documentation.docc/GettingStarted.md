# Getting Started with swift-persistence

Add persistence to your Swift app with a few lines of code.

## Installation

Add the package via Swift Package Manager in `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/no-problem-dev/swift-persistence.git",
        from: "2.0.0"
    )
]
```

Then add only the modules you need to your target's `dependencies`:

| Module | When to use |
|--------|-------------|
| `PersistenceCore` | Always — protocols and `PersistenceError` |
| `PersistenceUserDefaults` | Storing user preferences in UserDefaults |
| `PersistenceKeychain` | Storing API keys, tokens, credentials |
| `PersistenceFileSystem` | Storing documents or registries on disk |
| `PersistenceTesting` | In-memory doubles for unit tests |

## Basic Usage

### UserDefaults backend — `UserDefaultsKeyValueStore`

Use `UserDefaultsKeyValueStore` for lightweight user settings. Primitive types (`String`, `Bool`, `Int`, `Double`, `Data`) use native UserDefaults accessors; all other `Codable` types are JSON-encoded automatically.

```swift
import PersistenceUserDefaults

let store = UserDefaultsKeyValueStore()

// Write
try await store.setValue("dark", forKey: "theme")

// Read with convenience accessor
let theme: String? = try await store.string(forKey: "theme")

// Custom Codable type
struct AppPreferences: Codable, Sendable {
    var fontSize: Int
    var colorScheme: String
}
try await store.setValue(AppPreferences(fontSize: 14, colorScheme: "dark"), forKey: "prefs")
let prefs: AppPreferences? = try await store.value(forKey: "prefs", type: AppPreferences.self)
```

### Keychain backend — `KeychainSecureStore`

Use `KeychainSecureStore` for sensitive values such as API keys and session tokens. Items are stored under `kSecClassGenericPassword` and are encrypted by the OS.

```swift
import PersistenceKeychain

// Default: whenUnlockedThisDeviceOnly — no iCloud sync, device-only
let secrets = KeychainSecureStore(service: Bundle.main.bundleIdentifier ?? "com.example.app")

// Store an API key
try await secrets.setString("sk-live-abc123", forKey: "openai_api_key")

// Retrieve it
if let apiKey = try await secrets.getString(forKey: "openai_api_key") {
    // use apiKey
}

// For cross-device sharing, use .whenUnlocked
let sharedSecrets = KeychainSecureStore(
    service: "com.example.app",
    accessibility: .whenUnlocked
)
```

### File system backend — `FileSystemDocumentStore` and `FoundationFileSystem`

`FileSystemDocumentStore` persists each `Identifiable & Codable` document as a separate `{id}.json` file. `FoundationFileSystem` provides raw file tree access for directory scanning and file authoring.

```swift
import PersistenceFileSystem

struct Note: Codable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var body: String
}

// One-time setup — directory is created if absent
let store = try FileSystemDocumentStore<Note>(
    directory: URL.documentsDirectory.appendingPathComponent("notes")
)

// Create / update
let note = Note(id: UUID(), title: "Meeting notes", body: "...")
try await store.save(note)

// Read
let loaded = try await store.load(id: note.id)
let all: [Note] = try await store.loadAll()

// Delete
try await store.delete(id: note.id)
```

## Testing

Swap every production backend for an in-memory double from `PersistenceTesting` — no disk or Keychain access required.

```swift
import PersistenceTesting

// Inject via protocol types so the same code runs against both backends
let store: any KeyValueStore = InMemoryKeyValueStore()
let secrets: any SecureStore = InMemorySecureStore()
let docs: any DocumentStore = InMemoryDocumentStore<Note>()
let fs: any FileSystemReading & FileSystemWriting = InMemoryFileSystem()

// Pre-populate for deterministic tests
let seeded = InMemoryKeyValueStore(["theme": "dark"])
let fixedResolver = InMemoryKeyResolver(["API_KEY": "test-key-abc"])
```

## Error Handling

All operations throw `PersistenceError`. It conforms to `LocalizedError`, so `error.localizedDescription` returns a human-readable message that includes the key and underlying reason:

```swift
do {
    let value = try await store.value(forKey: "missing", type: String.self)
} catch let error as PersistenceError {
    // error.localizedDescription → "Item not found for key 'missing'."
    print(error.localizedDescription)
}
```
