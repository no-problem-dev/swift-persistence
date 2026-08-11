# Changelog

## [Unreleased]

## [3.0.0] - 2026-08-11

### Changed

- Builds and tests on Linux. Keychain has no Linux equivalent, so `KeychainSecureStore` is behind
  `#if canImport(Security)` and `PersistenceKeychain` becomes an empty module there rather than a
  build failure. `SecureStore` stays in `PersistenceCore` and remains available everywhere, so a
  Linux caller conforms their own type (libsecret, a KMS, an encrypted file) and injects it.


## [2.3.0] - 2026-07-19

See [GitHub Releases](../../releases) for changes up to and including this version.
