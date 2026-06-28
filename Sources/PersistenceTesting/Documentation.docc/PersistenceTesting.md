# ``PersistenceTesting``

In-memory test doubles for every `swift-persistence` protocol — no disk, no Keychain, no entitlements required in tests.

## Overview

`PersistenceTesting` provides a drop-in in-memory double for every protocol defined in `PersistenceCore`. The doubles are actor-isolated for data-race safety and can be pre-populated with seed data for deterministic test setups. Inject them through the protocol types so production code never needs to know which backend it is running against.

```swift
import PersistenceTesting

// Inject via protocol types — same interface as the production backends
let store: any KeyValueStore = InMemoryKeyValueStore()
let secrets: any SecureStore = InMemorySecureStore()
let docs: any DocumentStore = InMemoryDocumentStore<Note>()
let registry: any RegistryStore = InMemoryRegistryStore<ModelRecord>()
let fs: any FileSystemReading & FileSystemWriting = InMemoryFileSystem()
let resolver: any KeyResolver = InMemoryKeyResolver(["API_KEY": "test-key-abc"])
```

Each double matches the behaviour of its production counterpart: `InMemoryKeyValueStore` and `InMemorySecureStore` round-trip values through `JSONEncoder`/`JSONDecoder`, `InMemoryDocumentStore` throws ``PersistenceError/notFound(key:)`` on a missing ID, and `InMemoryFileSystem` builds an ancestor directory tree automatically on first write.

### Pre-populating seed data

All doubles except `InMemoryFileSystem` expose convenience initialisers for seeding:

```swift
// Pre-populate a key-value store with a mix of types
let kvStore = InMemoryKeyValueStore(["theme": "dark", "fontSize": 16])

// Pre-populate a registry
let regStore = InMemoryRegistryStore(["llama-3b": ModelRecord(downloadedAt: .now, sizeBytes: 1_800_000_000)])

// Fixed resolver for API key injection
let resolver = InMemoryKeyResolver(["OPENAI_API_KEY": "sk-test-abc"])
```

`InMemoryFileSystem` is built programmatically using its `addFile` and `addDirectory` methods before the system-under-test runs:

```swift
let fs = InMemoryFileSystem()

// Build a tree
let root = URL(fileURLWithPath: "/skills")
await fs.addFile(root.appendingPathComponent("writing/SKILL.md"), string: "# Writing\n")
await fs.addFile(root.appendingPathComponent("coding/SKILL.md"), string: "# Coding\n")

// The system under test traverses the tree without touching disk
let items = try await fs.contentsOfDirectory(root)
```

### Assertion helpers

`InMemoryKeyValueStore`, `InMemorySecureStore`, `InMemoryDocumentStore`, and `InMemoryRegistryStore` each expose a `count` property for concise XCTest assertions:

```swift
let store = InMemoryDocumentStore<Note>()
try await store.save(Note(id: UUID(), title: "Draft", body: ""))
let count = await store.count
XCTAssertEqual(count, 1)
```

## Topics

### Key-Value and Secure Storage Doubles

- ``InMemoryKeyValueStore``
- ``InMemorySecureStore``

### Document and Registry Storage Doubles

- ``InMemoryDocumentStore``
- ``InMemoryRegistryStore``

### File System Double

- ``InMemoryFileSystem``

### Key Resolution Double

- ``InMemoryKeyResolver``
