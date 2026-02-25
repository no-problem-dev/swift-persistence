English | [日本語](README.md)

# SwiftPersistence

A protocol-oriented persistence abstraction layer for Swift

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## Features

- **Protocol-Oriented** - All persistence operations defined as abstract protocols for DI and testability
- **KeyValueStore** - Type-safe UserDefaults abstraction (Codable support)
- **SecureStore** - Safe Keychain wrapper (API key and credential protection)
- **DocumentStore** - File-based CRUD (individual JSON files, atomic writes)
- **RegistryStore** - Single JSON file registry pattern
- **KeyResolver** - Multi-source fallback resolution: Info.plist → Keychain → UserDefaults
- **InMemory Test Doubles** - Bundled InMemory implementations for all protocols

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-persistence.git", .upToNextMajor(from: "1.0.0"))
]
```

### Module Structure

Import only the modules you need:

| Module | Purpose |
|--------|---------|
| `PersistenceCore` | Protocols + error types (Foundation only, no external dependencies) |
| `PersistenceUserDefaults` | UserDefaults-backed KeyValueStore implementation |
| `PersistenceKeychain` | Keychain-backed SecureStore implementation |
| `PersistenceFileSystem` | File-backed DocumentStore / RegistryStore implementations |
| `PersistenceTesting` | 5 InMemory implementations (test DI doubles) |

## Quick Start

### Key-Value Store (UserDefaults Abstraction)

```swift
import PersistenceUserDefaults

let store = UserDefaultsKeyValueStore()

// Save and retrieve Codable values
try store.setValue("dark", forKey: "theme")
let theme: String? = try store.string(forKey: "theme")

// Custom types supported
struct UserPrefs: Codable, Sendable {
    var fontSize: Int
    var language: String
}
try store.setValue(UserPrefs(fontSize: 14, language: "en"), forKey: "prefs")
let prefs: UserPrefs? = try store.value(forKey: "prefs", type: UserPrefs.self)
```

### Secure Store (Keychain Abstraction)

```swift
import PersistenceKeychain

let secrets = KeychainSecureStore(service: "com.example.myapp")

// Securely store API keys
try secrets.setString("sk-abc123...", forKey: "api_key")
let key = try secrets.getString(forKey: "api_key")
```

### Document Store (File-based CRUD)

```swift
import PersistenceFileSystem

struct Note: Codable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var body: String
}

let store = try FileSystemDocumentStore<Note>(
    directory: documentsURL.appendingPathComponent("notes")
)

// CRUD operations
let note = Note(id: UUID(), title: "Memo", body: "Content")
try store.save(note)
let all = try store.loadAll()
try store.delete(id: note.id)
```

### Registry Store (Single JSON Registry)

```swift
import PersistenceFileSystem

struct CacheEntry: Codable, Sendable {
    let version: String
    let downloadedAt: Date
}

let registry = FileSystemRegistryStore<CacheEntry>(
    directory: cacheURL,
    filename: "registry.json"
)

var entries = registry.load()
entries["model-v1"] = CacheEntry(version: "1.0", downloadedAt: Date())
try registry.save(entries)
```

### Multi-Source Fallback Resolution

```swift
import PersistenceCore
import PersistenceKeychain
import PersistenceUserDefaults

let resolver = ChainedKeyResolver(
    secureStore: KeychainSecureStore(service: "com.example.myapp"),
    keyValueStore: UserDefaultsKeyValueStore(),
    keyMapping: [
        "API_KEY": .init(secure: "api_key", keyValue: "api_key"),
    ]
)

// Searches in order: Info.plist → Keychain → UserDefaults
let apiKey = resolver.resolve("API_KEY")
```

### InMemory Test Doubles

```swift
import PersistenceTesting

// Inject via DI in tests
let mockStore = InMemoryKeyValueStore()
let mockSecrets = InMemorySecureStore()
let mockDocs = InMemoryDocumentStore<Note>()

let settings = AppSettings(
    preferences: mockStore,
    secrets: mockSecrets,
    keyResolver: InMemoryKeyResolver(values: ["API_KEY": "test-key"])
)
```

## Architecture

2-layer architecture for separation of concerns:

```
Layer 0: PersistenceCore           Protocols + error types (no external dependencies)
Layer 1: PersistenceUserDefaults   UserDefaults concrete implementation
         PersistenceKeychain       Keychain concrete implementation
         PersistenceFileSystem     File system concrete implementation
         PersistenceTesting        InMemory test doubles
```

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+
- Xcode 16.0+

## License

MIT License - See [LICENSE](LICENSE) for details

## Links

- [Report Issues](https://github.com/no-problem-dev/swift-persistence/issues)
- [Discussions](https://github.com/no-problem-dev/swift-persistence/discussions)
