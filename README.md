English | [日本語](./README.ja.md)

# SwiftPersistence

Read and write app data through one protocol, whichever store it lands in — so a use case can be tested without UserDefaults, the Keychain, or the disk.

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

Your domain and use-case layers depend on a protocol; the composition root picks whether that
protocol is backed by `UserDefaults`, the Keychain, the file system, or nothing at all.

## Features

- **Protocol-oriented** — every storage operation is an abstract protocol, so a use case can be
  tested without touching disk, the Keychain, or an entitlement
- **KeyValueStore** — a type-safe `UserDefaults` abstraction; primitives go through native accessors
  and any other `Codable` type is JSON-encoded automatically
- **SecureStore** — a Keychain wrapper for API keys and credentials, with an explicit accessibility
  policy that defaults to this-device-only
- **DocumentStore** — file-backed CRUD, one JSON file per document, written atomically
- **RegistryStore** — a whole `[String: Codable]` dictionary in a single JSON file, for caches and
  metadata indexes
- **KeyResolver** — multi-source fallback in a fixed order: `Info.plist`, then Keychain, then
  `UserDefaults`
- **In-memory doubles for every protocol** — seedable, actor-isolated, and shipped in their own
  module so they never reach a production target

## Quick Start

```swift
import PersistenceUserDefaults

let store = UserDefaultsKeyValueStore()

try await store.setValue("dark", forKey: "theme")
let theme: String? = try await store.string(forKey: "theme")
```

Depend on the protocol, not the backend, and the same code runs against the real store in the app
and against an in-memory double in tests:

```swift
import PersistenceCore
import PersistenceTesting

let store: any KeyValueStore = InMemoryKeyValueStore(["theme": "dark"])
```

## Documentation

[**API reference and guides**](https://no-problem-dev.github.io/swift-persistence/documentation/persistencecore/) —
including [Getting Started](https://no-problem-dev.github.io/swift-persistence/documentation/persistencecore/gettingstarted/)
and [Architecture](https://no-problem-dev.github.io/swift-persistence/documentation/persistencecore/architecture/),
which explains what each backend guarantees about durability, threading, and decode failure.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-persistence.git", .upToNextMajor(from: "2.0.0"))
]
```

Add only the modules a target actually needs:

```swift
.product(name: "PersistenceCore",         package: "swift-persistence"),
.product(name: "PersistenceUserDefaults", package: "swift-persistence"),
.product(name: "PersistenceKeychain",     package: "swift-persistence"),
.product(name: "PersistenceFileSystem",   package: "swift-persistence"),
.product(name: "PersistenceTesting",      package: "swift-persistence"),  // test targets only
```

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+
- Xcode 16.0+

## License

MIT — see [LICENSE](LICENSE).
