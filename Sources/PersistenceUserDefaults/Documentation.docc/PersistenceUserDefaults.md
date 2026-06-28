# ``PersistenceUserDefaults``

`UserDefaults`-backed ``KeyValueStore`` implementation for lightweight user preference storage.

## Overview

`PersistenceUserDefaults` provides `UserDefaultsKeyValueStore`, the concrete ``KeyValueStore`` for storing user preferences in `UserDefaults`. It is the go-to backend for settings that should persist across app launches but do not require encryption — theme selection, feature flags, tutorial progress, and similar lightweight state.

`UserDefaultsKeyValueStore` is an `actor`, so reads and writes automatically hop off the caller's actor, making it safe to call from `@MainActor` view models without blocking the main thread.

Primitive types (`String`, `Bool`, `Int`, `Double`, `Data`) use `UserDefaults`' native accessors for efficiency. Any other `Codable` type is transparently round-tripped through `JSONEncoder`/`JSONDecoder`:

```swift
import PersistenceUserDefaults

let store = UserDefaultsKeyValueStore()

// Write a primitive value
try await store.setValue(true, forKey: "notifications_enabled")

// Read it back with a typed convenience accessor
let enabled: Bool? = try await store.bool(forKey: "notifications_enabled")

// Custom Codable type — encoded as JSON automatically
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

For a shared container (App Groups), pass a `suiteName` at initialisation:

```swift
let sharedStore = UserDefaultsKeyValueStore(suiteName: "group.com.example.app")
```

In test targets, replace `UserDefaultsKeyValueStore` with `InMemoryKeyValueStore` from `PersistenceTesting`. Both conform to ``KeyValueStore``, so no production code needs to change.

## Topics

### Implementation

- ``UserDefaultsKeyValueStore``
