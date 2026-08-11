# ``PersistenceKeychain``

Encrypted, on-device storage for credentials and secrets, backed by the system Keychain.

## Overview

`PersistenceKeychain` provides `KeychainSecureStore`, a concrete ``SecureStore`` for values that must be encrypted at rest and must survive a reinstall — API keys, OAuth tokens, session credentials, and any secret you must not write in the clear to `UserDefaults` or to disk.

Internally, each entry is stored as a `kSecClassGenericPassword` Keychain item: the logical key maps to the `kSecAttrAccount` attribute, and a configurable service identifier maps to `kSecAttrService`. Every write is an upsert — update if the item exists, add if it does not — so repeated calls to `setString` or `setData` for the same key are safe.

`KeychainSecureStore` is an actor, so Keychain IPC hops off the calling actor automatically and the store is safe to call from a `@MainActor` view model.

A `KeychainAccessibility` policy controls when a Keychain item can be read and whether it syncs to iCloud Keychain. The recommended default — ``KeychainAccessibility/whenUnlockedThisDeviceOnly`` — grants access only while the device is unlocked and keeps the item off iCloud Keychain, satisfying the Apple Review §2.1 data protection requirement:

```swift
import PersistenceKeychain

// Default: whenUnlockedThisDeviceOnly — encrypted, device-only, never synced to iCloud
let secrets = KeychainSecureStore(
    service: Bundle.main.bundleIdentifier ?? "com.example.app"
)

// Store an API key
try await secrets.setString("sk-live-abc123", forKey: "openai_api_key")

// Read it back
if let apiKey = try await secrets.getString(forKey: "openai_api_key") {
    // Use apiKey
}

// Remove it, for example when the user signs out
try await secrets.remove(forKey: "openai_api_key")
```

Use `afterFirstUnlockThisDeviceOnly` for credentials a background task needs, which are readable from the first unlock after a restart. Use `whenUnlocked` for credentials that should roam across the user's devices through iCloud Keychain:

```swift
// Reachable from the background, and never leaves this device
let backgroundSecrets = KeychainSecureStore(
    service: "com.example.app",
    accessibility: .afterFirstUnlockThisDeviceOnly
)

// Roams across the user's devices through iCloud Keychain
let cloudSecrets = KeychainSecureStore(
    service: "com.example.app",
    accessibility: .whenUnlocked
)
```

Pass an `accessGroup` to share items between apps through an App Group Keychain:

```swift
let sharedSecrets = KeychainSecureStore(
    service: "com.example.app",
    accessGroup: "$(AppIdentifierPrefix)group.com.example.shared"
)
```

In test targets, replace `KeychainSecureStore` with `InMemorySecureStore` from `PersistenceTesting`. Both conform to ``SecureStore``, so tests need neither entitlements nor access to a real Keychain.

## Topics

### Implementation

- ``KeychainSecureStore``

### Accessibility Policies

- ``KeychainAccessibility``
