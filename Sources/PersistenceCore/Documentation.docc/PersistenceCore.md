# ``PersistenceCore``

Protocol-oriented persistence abstractions for Swift — type-safe, async-ready, and fully testable.

## Overview

`PersistenceCore` defines the protocol surface and shared error type for the `swift-persistence` family. It has no external dependencies beyond Foundation, making it safe to use in any layer of your architecture — domain, use-case, or infrastructure alike.

The package organises storage into two layers. **Layer 0 — `PersistenceCore`** (this module) owns the protocols, ``PersistenceError``, and the ``ChainedKeyResolver`` utility. Import it in your domain and use-case layer: your business logic depends only on the protocol types — ``KeyValueStore``, ``SecureStore``, ``DocumentStore``, ``RegistryStore``, ``FileSystemReading``, and ``FileSystemWriting`` — never on a concrete backend.

**Layer 1** provides the concrete implementations and test doubles as separate importable modules so you pull in only what you need.

`PersistenceUserDefaults` delivers `UserDefaultsKeyValueStore`, a ``KeyValueStore`` backed by `UserDefaults`. Primitive types — `String`, `Bool`, `Int`, `Double`, `Data` — use native UserDefaults accessors for efficiency; any other `Codable` type is round-tripped through `JSONEncoder`/`JSONDecoder` automatically. Import `PersistenceUserDefaults` in your infrastructure layer for lightweight user preferences such as theme selection, feature flags, and on-boarding state.

`PersistenceKeychain` delivers `KeychainSecureStore`, a ``SecureStore`` backed by the system Keychain via `kSecClassGenericPassword`. Items are protected by a configurable `KeychainAccessibility` policy — the default (`whenUnlockedThisDeviceOnly`) prevents iCloud Keychain sync and satisfies Apple Review §2.1 data-protection requirements. Import `PersistenceKeychain` for API keys, session tokens, and any secret that must survive app reinstall and be encrypted at rest.

`PersistenceFileSystem` delivers three concrete types. `FileSystemDocumentStore` persists each `Identifiable & Codable` document as an individual `{id}.json` file using atomic writes to prevent corruption. `FileSystemRegistryStore` persists an entire `[String: Codable]` dictionary as a single JSON file, ideal for caches and metadata registries. `FoundationFileSystem` wraps `FileManager` and conforms to both ``FileSystemReading`` and ``FileSystemWriting``, covering raw tree traversal — existence checks, directory listing, file reads, atomic writes, moves, and deletions. Import `PersistenceFileSystem` in your infrastructure layer for document or file-tree persistence.

`PersistenceTesting` provides in-memory doubles for every protocol in this module — `InMemoryKeyValueStore`, `InMemorySecureStore`, `InMemoryDocumentStore`, `InMemoryRegistryStore`, `InMemoryFileSystem`, and `InMemoryKeyResolver`. All doubles are actors for data-race safety and can be pre-populated with seed data for deterministic test setups. Import `PersistenceTesting` in test targets only; inject the doubles through the protocol types so your production code remains decoupled from any backend.

```
PersistenceCore (protocols + error)
  ├── PersistenceUserDefaults   → UserDefaultsKeyValueStore
  ├── PersistenceKeychain       → KeychainSecureStore, KeychainAccessibility
  ├── PersistenceFileSystem     → FileSystemDocumentStore, FileSystemRegistryStore, FoundationFileSystem
  └── PersistenceTesting        → InMemory* doubles for all protocols
```

See <doc:GettingStarted> for installation and per-backend usage examples.

## Topics

### Essentials

- <doc:GettingStarted>

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
