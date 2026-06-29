# ``PersistenceCore``

プロトコル指向の永続化抽象 — 型安全・非同期対応・完全テスト可能。

## Overview

`PersistenceCore` は `swift-persistence` ファミリーのプロトコル面と共有エラー型を定義する。Foundation 以外の外部依存がなく、ドメイン・ユースケース・インフラのどのアーキテクチャ層でも安全にインポートできる。

パッケージのストレージは 2 層に分かれる。**Layer 0 — `PersistenceCore`**（このモジュール）がプロトコル・``PersistenceError``・``ChainedKeyResolver`` ユーティリティを所有する。ドメイン層・ユースケース層にインポートし、ビジネスロジックはプロトコル型（``KeyValueStore``、``SecureStore``、``DocumentStore``、``RegistryStore``、``FileSystemReading``、``FileSystemWriting``）にのみ依存させ、具体的なバックエンドには依存させない。

**Layer 1** は具体的な実装とテストダブルを独立したインポート可能なモジュールとして提供し、必要なものだけを取り込める。

`PersistenceUserDefaults` は `UserDefaultsKeyValueStore`（``KeyValueStore`` の `UserDefaults` 実装）を提供する。プリミティブ型（`String`、`Bool`、`Int`、`Double`、`Data`）はネイティブアクセサで効率的に処理し、それ以外の `Codable` 型は `JSONEncoder`/`JSONDecoder` で自動変換する。テーマ選択・フィーチャーフラグ・オンボーディング状態などの軽量なユーザー設定にはインフラ層で `PersistenceUserDefaults` を使用する。

`PersistenceKeychain` は `KeychainSecureStore`（``SecureStore`` の Keychain 実装）を提供する。各エントリは `kSecClassGenericPassword` Keychain アイテムとして保護され、設定可能な `KeychainAccessibility` ポリシーで管理する。デフォルト（`whenUnlockedThisDeviceOnly`）は iCloud Keychain 同期を抑制し Apple Review §2.1 データ保護要件を満たす。API キー・セッショントークン・アプリ再インストール後も残す必要があり平文で保存してはいけないシークレットには `PersistenceKeychain` を使用する。

`PersistenceFileSystem` は 3 つの具体型を提供する。`FileSystemDocumentStore` は各 `Identifiable & Codable` ドキュメントを個別の `{id}.json` ファイルとしてアトミック書き込みで永続化し破損を防ぐ。`FileSystemRegistryStore` は `[String: Codable]` 辞書全体を単一 JSON ファイルとして永続化し、キャッシュやメタデータレジストリに適している。`FoundationFileSystem` は `FileManager` をラップし ``FileSystemReading`` と ``FileSystemWriting`` の両方に準拠して、存在確認・ディレクトリ一覧・ファイル読み取り・アトミック書き込み・移動・削除という生のツリー走査操作をカバーする。ドキュメントやファイルツリーの永続化にはインフラ層で `PersistenceFileSystem` を使用する。

`PersistenceTesting` はこのモジュールの全プロトコルに対応するインメモリダブルを提供する — `InMemoryKeyValueStore`、`InMemorySecureStore`、`InMemoryDocumentStore`、`InMemoryRegistryStore`、`InMemoryFileSystem`、`InMemoryKeyResolver`。全ダブルはアクター分離によりデータレース安全で、決定的なテストセットアップのためにシードデータを事前設定できる。テストターゲットのみに `PersistenceTesting` をインポートし、プロトコル型を通じてダブルを注入することでプロダクションコードはバックエンドから切り離される。

```
PersistenceCore (プロトコル + エラー)
  ├── PersistenceUserDefaults   → UserDefaultsKeyValueStore
  ├── PersistenceKeychain       → KeychainSecureStore, KeychainAccessibility
  ├── PersistenceFileSystem     → FileSystemDocumentStore, FileSystemRegistryStore, FoundationFileSystem
  └── PersistenceTesting        → 全プロトコルの InMemory* ダブル
```

インストールとバックエンド別の使用例は <doc:GettingStarted> を参照。

## Topics

### はじめに

- <doc:GettingStarted>

### キーバリューストレージ

- ``KeyValueStore``

### セキュアストレージ

- ``SecureStore``

### ドキュメントストレージ

- ``DocumentStore``

### レジストリストレージ

- ``RegistryStore``

### ファイルシステム

- ``FileSystemReading``
- ``FileSystemWriting``

### キー解決

- ``KeyResolver``
- ``ChainedKeyResolver``

### エラー

- ``PersistenceError``
