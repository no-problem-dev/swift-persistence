# ``PersistenceCore``

Protocol-oriented persistence abstractions that are type safe, async-ready, and fully testable.

## Overview

`PersistenceCore` defines the protocol surface and the shared error type for the `swift-persistence` family. It has no dependencies beyond Foundation, so you can import it safely from any architectural layer — domain, use case, or infrastructure.

Storage in this package is split across two layers. **Layer 0 — `PersistenceCore`** (this module) owns the protocols, ``PersistenceError``, and the ``ChainedKeyResolver`` utility. Import it into your domain and use case layers so that business logic depends only on protocol types (``KeyValueStore``, ``SecureStore``, ``DocumentStore``, ``RegistryStore``, ``FileSystemReading``, ``FileSystemWriting``) and never on a concrete backend.

**Layer 1** ships the concrete implementations and the test doubles as separately importable modules, so you take on only what you use.

`PersistenceUserDefaults` provides `UserDefaultsKeyValueStore`, a `UserDefaults` implementation of ``KeyValueStore``. Primitive types (`String`, `Bool`, `Int`, `Double`, `Data`) go through the native accessors; every other `Codable` type is converted with `JSONEncoder` and `JSONDecoder`. Use it from the infrastructure layer for lightweight user settings such as theme selection, feature flags, and onboarding state.

`PersistenceKeychain` provides `KeychainSecureStore`, a Keychain implementation of ``SecureStore``. Each entry is protected as a `kSecClassGenericPassword` Keychain item governed by a configurable `KeychainAccessibility` policy. The default, `whenUnlockedThisDeviceOnly`, keeps items off iCloud Keychain and satisfies the Apple Review §2.1 data protection requirement. Use it for API keys, session tokens, and any secret that has to survive a reinstall and must never be written in the clear.

`PersistenceFileSystem` provides three concrete types. `FileSystemDocumentStore` persists each `Identifiable & Codable` document as its own `{id}.json` file, writing atomically so that a failed write cannot corrupt an existing file. `FileSystemRegistryStore` persists an entire `[String: Codable]` dictionary as a single JSON file, which suits caches and metadata registries. `FoundationFileSystem` wraps `FileManager` and conforms to both ``FileSystemReading`` and ``FileSystemWriting``, covering the raw tree-walking operations: existence checks, directory listings, file reads, atomic writes, moves, and deletes. Use it from the infrastructure layer whenever you persist documents or walk a file tree.

`PersistenceTesting` provides an in-memory double for every protocol in this module — `InMemoryKeyValueStore`, `InMemorySecureStore`, `InMemoryDocumentStore`, `InMemoryRegistryStore`, `InMemoryFileSystem`, and `InMemoryKeyResolver`. Every double is data-race safe: five of them are actors, and `InMemoryKeyResolver` is an immutable value type. Several accept fixture data at initialisation, which keeps test setup deterministic. Import `PersistenceTesting` only from test targets and inject the doubles through protocol types, so production code stays independent of any backend.

```
PersistenceCore (protocols + errors)
  ├── PersistenceUserDefaults   → UserDefaultsKeyValueStore
  ├── PersistenceKeychain       → KeychainSecureStore, KeychainAccessibility
  ├── PersistenceFileSystem     → FileSystemDocumentStore, FileSystemRegistryStore, FoundationFileSystem
  └── PersistenceTesting        → InMemory* doubles for every protocol
```

For installation and per-backend examples, see <doc:GettingStarted>.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Architecture>

### Key-Value Storage

- ``KeyValueStore``

### Secure Storage

- ``SecureStore``

### Document Storage

- ``DocumentStore``

### Registry Storage

- ``RegistryStore``

### File System

- ``FileSystemReading``
- ``FileSystemWriting``

### Key Resolution

- ``KeyResolver``
- ``ChainedKeyResolver``

### Errors

- ``PersistenceError``
