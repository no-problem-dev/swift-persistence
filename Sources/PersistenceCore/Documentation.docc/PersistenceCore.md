# ``PersistenceCore``

Protocol-oriented persistence abstractions for Swift — type-safe, async-ready, and fully testable.

## Overview

`PersistenceCore` defines the protocol surface and shared error type for the swift-persistence family of packages. It has no external dependencies beyond Foundation, making it safe to use in any layer of your architecture.

The package is organised in two layers:

- **Layer 0 — `PersistenceCore`**: Protocols, `PersistenceError`, and utilities. Import this in your domain/use-case layer.
- **Layer 1 — Concrete implementations**: `PersistenceUserDefaults`, `PersistenceKeychain`, `PersistenceFileSystem`. Import these in your infrastructure layer. `PersistenceTesting` ships in-memory doubles for every protocol so production code never touches disk or Keychain in tests.

```
PersistenceCore (protocols + error)
  ├── PersistenceUserDefaults   → UserDefaultsKeyValueStore
  ├── PersistenceKeychain       → KeychainSecureStore
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
