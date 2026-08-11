# ``PersistenceTesting``

In-memory test doubles for every persistence protocol — no disk, no Keychain, no entitlements.

## Overview

`PersistenceTesting` provides a drop-in, in-memory double for every protocol defined in `PersistenceCore`. All of them are data-race safe: five are actors, and `InMemoryKeyResolver` is an immutable value type. Injecting them through protocol types keeps production code unaware of which backend it is running against.

```swift
import PersistenceCore
import PersistenceTesting

// Inject through protocol types — the same interface as the production backends
let store: any KeyValueStore = InMemoryKeyValueStore()
let secrets: any SecureStore = InMemorySecureStore()
let docs: any DocumentStore<Note> = InMemoryDocumentStore<Note>()
let registry: any RegistryStore<ModelRecord> = InMemoryRegistryStore<ModelRecord>()
let fs: any FileSystemReading & FileSystemWriting = InMemoryFileSystem()
let resolver: any KeyResolver = InMemoryKeyResolver(["API_KEY": "test-key-abc"])
```

Each double matches the observable behaviour of its production counterpart: `InMemoryKeyValueStore` round-trips values through `JSONEncoder` and `JSONDecoder`, `InMemorySecureStore` stores raw bytes and converts strings as UTF-8 exactly as the Keychain store does, `InMemoryDocumentStore` throws ``PersistenceError/notFound(key:)`` for an unknown ID, and `InMemoryFileSystem` registers the ancestor directories of a path on the first write.

### Seeding fixture data

`InMemoryKeyValueStore`, `InMemoryRegistryStore`, and `InMemoryKeyResolver` take their initial contents in an initialiser:

```swift
// Preload a key-value store, mixing value types
let kvStore = InMemoryKeyValueStore(["theme": "dark", "fontSize": 16])

// Preload a registry
let regStore = InMemoryRegistryStore(["llama-3b": ModelRecord(downloadedAt: .now, sizeBytes: 1_800_000_000)])

// A fixed resolver for injecting API keys
let resolver = InMemoryKeyResolver(["OPENAI_API_KEY": "sk-test-abc"])
```

`InMemoryDocumentStore` and `InMemorySecureStore` have no seeding initialiser. Fill them through their regular write methods before exercising the system under test:

```swift
let docs = InMemoryDocumentStore<Note>()
try await docs.save(Note(id: noteID, title: "Draft", body: ""))

let secrets = InMemorySecureStore()
try await secrets.setString("sk-test-abc", forKey: "openai_api_key")
```

Build `InMemoryFileSystem` programmatically with its `addFile` and `addDirectory` methods:

```swift
let fs = InMemoryFileSystem()

// Build the tree
let root = URL(fileURLWithPath: "/skills")
await fs.addFile(root.appendingPathComponent("writing/SKILL.md"), string: "# Writing\n")
await fs.addFile(root.appendingPathComponent("coding/SKILL.md"), string: "# Coding\n")

// The system under test walks the tree without touching disk
let items = try await fs.contentsOfDirectory(root)
```

### Assertion helpers

`InMemoryKeyValueStore`, `InMemorySecureStore`, `InMemoryDocumentStore`, and `InMemoryRegistryStore` each expose a `count` property for concise assertions:

```swift
let store = InMemoryDocumentStore<Note>()
try await store.save(Note(id: UUID(), title: "Draft", body: ""))
let count = await store.count
#expect(count == 1)
```

## Topics

### Key-Value and Secure Storage Doubles

- ``InMemoryKeyValueStore``
- ``InMemorySecureStore``

### Document and Registry Storage Doubles

- ``InMemoryDocumentStore``
- ``InMemoryRegistryStore``

### File System Doubles

- ``InMemoryFileSystem``

### Key Resolution Doubles

- ``InMemoryKeyResolver``
