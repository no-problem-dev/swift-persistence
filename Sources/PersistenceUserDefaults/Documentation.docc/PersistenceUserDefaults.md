# ``PersistenceUserDefaults``

Lightweight storage for user settings and feature flags, backed by the system defaults database.

## Overview

`PersistenceUserDefaults` provides `UserDefaultsKeyValueStore`, a concrete ``KeyValueStore`` that keeps settings in `UserDefaults`: values that must survive app launches but do not need encryption — theme selection, feature flags, tutorial progress, and similar lightweight state.

`UserDefaultsKeyValueStore` is an actor, so reads and writes hop off the calling actor automatically. It is safe to call from a `@MainActor` view model without blocking the main thread.

Primitive types (`String`, `Bool`, `Int`, `Double`, `Data`) use the native `UserDefaults` accessors. Every other `Codable` type is converted transparently with `JSONEncoder` and `JSONDecoder`:

```swift
import PersistenceUserDefaults

let store = UserDefaultsKeyValueStore()

// Write a primitive value
try await store.setValue(true, forKey: "notifications_enabled")

// Read through a typed convenience accessor
let enabled: Bool? = try await store.bool(forKey: "notifications_enabled")

// Custom Codable types are JSON-encoded automatically
struct AppPreferences: Codable, Sendable {
    var fontSize: Int
    var colorScheme: String
}

try await store.setValue(
    AppPreferences(fontSize: 16, colorScheme: "dark"),
    forKey: "prefs"
)
let prefs: AppPreferences? = try await store.value(forKey: "prefs", type: AppPreferences.self)
```

Pass a `suiteName` at initialisation to use a shared container such as an App Group:

```swift
let sharedStore = UserDefaultsKeyValueStore(suiteName: "group.com.example.app")
```

In test targets, replace `UserDefaultsKeyValueStore` with `InMemoryKeyValueStore` from `PersistenceTesting`. Both conform to ``KeyValueStore``, so production code does not change.

## Topics

### Implementation

- ``UserDefaultsKeyValueStore``
