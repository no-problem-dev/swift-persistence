# Architecture

Two layers, five modules, and what each backend actually guarantees about durability, threading,
and a value that no longer decodes.

## Overview

The package is split so that the layers of an app that care *what* is stored never see *where* it
is stored.

**Layer 0 — `PersistenceCore`** owns the protocols, ``PersistenceError``, and ``ChainedKeyResolver``.
It depends on nothing beyond Foundation, so it is safe to import from a domain or use-case layer.
Business logic depends on ``KeyValueStore``, ``SecureStore``, ``DocumentStore``, ``RegistryStore``,
``FileSystemReading`` and ``FileSystemWriting`` — never on a concrete type.

**Layer 1** holds the concrete backends, each in its own importable module so a target takes only
what it uses.

| Module | Provides | Backed by |
|---|---|---|
| `PersistenceCore` | protocols, ``PersistenceError``, ``ChainedKeyResolver`` | Foundation only |
| `PersistenceUserDefaults` | `UserDefaultsKeyValueStore` | the user defaults database |
| `PersistenceKeychain` | `KeychainSecureStore`, `KeychainAccessibility` | the system Keychain |
| `PersistenceFileSystem` | `FileSystemDocumentStore`, `FileSystemRegistryStore`, `FoundationFileSystem` | the local disk |
| `PersistenceTesting` | six `InMemory*` doubles | nothing; process memory |

Only the composition root imports a Layer 1 module. Test targets import `PersistenceTesting` and
nothing else, which is what keeps the doubles out of a shipping binary.

## What each backend guarantees

Two backends satisfying the same protocol do not behave the same way, and the differences are the
ones that bite in production: whether a write is on disk, whether concurrent calls are safe, and
what a read does when the bytes no longer match the type.

### Durability

| Backend | On a normal write | On process kill | On power loss | In a backup |
|---|---|---|---|---|
| `UserDefaultsKeyValueStore` | updates memory, reaches disk at the system's next flush | write may be lost | write may be lost | yes |
| `KeychainSecureStore` | committed by the Keychain daemon before the call returns | retained | retained | only the non-`thisDeviceOnly` accessibility classes |
| `FileSystemDocumentStore` | one file replaced atomically | retained | may be lost — nothing is flushed | yes |
| `FileSystemRegistryStore` | whole file rewritten atomically | retained | may be lost — nothing is flushed | yes |
| `FoundationFileSystem` | file replaced atomically, parents created first | retained | may be lost — nothing is flushed | yes |
| every `InMemory*` | nothing leaves memory | lost | lost | no |

"Atomically" here means a reader sees either the whole previous file or the whole new one — never a
half-written document. It does not mean the bytes have reached the platter.

`UserDefaultsKeyValueStore` is **not a security boundary**: values land in a plain property list
inside the app container and travel in backups. Secrets belong in a ``SecureStore``.

No item written by `KeychainSecureStore` syncs through iCloud Keychain — the store never sets
`kSecAttrSynchronizable` — so the only way an item leaves the device is an encrypted backup, and
the `thisDeviceOnly` classes are excluded even from that. The default is
`whenUnlockedThisDeviceOnly`.

`FileSystemRegistryStore` rewrites the file with exactly the dictionary it is handed, so an entry
the caller dropped is gone from disk.

### Threading

Every store except one is an `actor`, so calls are serialised and it is safe to share an instance
across tasks. The I/O inside is synchronous, which means a call occupies that actor's executor for
the whole read or write — a large document blocks other calls to the same store, though not the
caller's actor.

`FoundationFileSystem` is the exception: it is a stateless `struct`, and because
`FileManager.default` is safe to use from several threads, any number of tasks can read through it
at once. Its methods are `async` but never suspend; each one holds a cooperative thread until the
disk answers.

### Decode failure

This is where the backends differ most, and where a silent one costs the most.

| Backend | A stored value that no longer decodes |
|---|---|
| `UserDefaultsKeyValueStore` | **throws** ``PersistenceError/decodingFailed(key:reason:)`` for non-primitive types; the bytes stay, so the read keeps failing until the key is overwritten or removed. Primitive types answer `nil` on a type mismatch, except Booleans and numbers, which the defaults database coerces — a key holding `"1"` reads back as `true` |
| `KeychainSecureStore` | reading a stored value that is not valid UTF-8 as a string fails; the item is left in place |
| `FileSystemDocumentStore` — `load(id:)` | **throws** ``PersistenceError/decodingFailed(key:reason:)``; the file is left in place |
| `FileSystemDocumentStore` — `loadAll()` | **skips the file silently.** A document left over from an older schema simply disappears from the result, and a short result cannot be told from a small store |
| `FileSystemRegistryStore` — `load()` | **returns an empty dictionary.** A missing file, truncated JSON, and an entry that no longer matches `Entry` are indistinguishable, and the next `save(_:)` overwrites the file that could have been recovered by hand. Take a copy before changing `Entry` |
| `InMemoryKeyValueStore` | **throws.** Every value round-trips through JSON, so reading a key as the wrong type fails here even where the defaults-backed store would answer `nil` or coerce |

The two silent ones — `loadAll()` and the registry's `load()` — are the cases worth designing
around. Neither logs.

## Keys on disk

`FileSystemDocumentStore` writes each document to `<id>.json`, using the identifier's text verbatim
with no escaping. An identifier containing a slash resolves into a subdirectory that was never
created, so saving it fails. Identifiers must be usable as a single path component.

`KeychainSecureStore` puts each key in the account attribute of its own generic-password item under
a shared service name, so two stores built with different service names never see each other's
items and deleting one key leaves the rest alone.

`ChainedKeyResolver` looks in the app bundle, then secure storage, then the key-value store, and
returns the first non-blank answer. A logical name absent from its `keyMapping` is looked up in the
bundle only — the other two sources are skipped, so an unmapped key resolves to `nil` even when
secure storage holds it under the same name.

## Testing against the doubles

The `InMemory*` types satisfy the same protocols and are actor-isolated, but they model only the
success paths. `InMemorySecureStore` never raises the locked-device or missing-entitlement failures
the real Keychain does, and `InMemoryKeyValueStore` is *stricter* than the defaults-backed store
about types. Code that passes against a double can still surprise against the real backend, so keep
at least one test that runs against the real one for anything where the difference matters.
