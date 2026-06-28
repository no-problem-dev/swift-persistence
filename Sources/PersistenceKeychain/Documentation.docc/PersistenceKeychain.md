# ``PersistenceKeychain``

Keychain-backed ``SecureStore`` implementation for encrypted credential and secret storage.

## Overview

`PersistenceKeychain` provides `KeychainSecureStore`, the concrete ``SecureStore`` for values that must be encrypted at rest and survive app reinstall — API keys, OAuth tokens, session credentials, and other secrets that must not be stored in `UserDefaults` or on disk in plaintext.

Under the hood, `KeychainSecureStore` stores each entry as a `kSecClassGenericPassword` Keychain item, with the logical key mapped to the `kSecAttrAccount` attribute and a configurable service identifier mapped to `kSecAttrService`. All writes are upserts (update if exists, add if not), so repeated calls to `setString` or `setData` for the same key are safe.

`KeychainSecureStore` is an `actor`, so Keychain IPC is automatically moved off the caller's actor, making it safe to call from `@MainActor` view models.

The `KeychainAccessibility` policy controls when the Keychain item can be read and whether it syncs to iCloud Keychain. The recommended default — ``KeychainAccessibility/whenUnlockedThisDeviceOnly`` — grants access only while the device is unlocked and suppresses iCloud sync, satisfying Apple Review §2.1 data-protection requirements:

```swift
import PersistenceKeychain

// Default: whenUnlockedThisDeviceOnly — encrypted, device-only, no iCloud sync
let secrets = KeychainSecureStore(
    service: Bundle.main.bundleIdentifier ?? "com.example.app"
)

// Store an API key
try await secrets.setString("sk-live-abc123", forKey: "openai_api_key")

// Retrieve it
if let apiKey = try await secrets.getString(forKey: "openai_api_key") {
    // use apiKey
}

// Remove it (e.g., on sign-out)
try await secrets.remove(forKey: "openai_api_key")
```

For credentials that must be available to background tasks (after first device unlock following reboot), use `afterFirstUnlockThisDeviceOnly`. For credentials that must roam across a user's devices via iCloud Keychain, use `whenUnlocked`:

```swift
// Background-accessible, device-only
let backgroundSecrets = KeychainSecureStore(
    service: "com.example.app",
    accessibility: .afterFirstUnlockThisDeviceOnly
)

// Roams to iCloud Keychain across devices
let cloudSecrets = KeychainSecureStore(
    service: "com.example.app",
    accessibility: .whenUnlocked
)
```

For cross-app sharing via an App Group Keychain, pass an `accessGroup`:

```swift
let sharedSecrets = KeychainSecureStore(
    service: "com.example.app",
    accessGroup: "$(AppIdentifierPrefix)group.com.example.shared"
)
```

In test targets, replace `KeychainSecureStore` with `InMemorySecureStore` from `PersistenceTesting`. Both conform to ``SecureStore``, so no entitlements or real Keychain access is required during testing.

## Topics

### Implementation

- ``KeychainSecureStore``

### Accessibility Policy

- ``KeychainAccessibility``
