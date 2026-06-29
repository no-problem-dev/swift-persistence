# ``PersistenceTesting``

全 `swift-persistence` プロトコル対応のインメモリテストダブル — テストにディスク・Keychain・エンタイトルメントは不要。

## Overview

`PersistenceTesting` は `PersistenceCore` で定義される全プロトコルに対応するドロップイン型のインメモリダブルを提供する。ダブルはアクター分離によりデータレース安全で、決定的なテストセットアップのためにシードデータを事前設定できる。プロトコル型を通じて注入することでプロダクションコードはバックエンドを意識しない。

```swift
import PersistenceTesting

// プロトコル型で注入 — プロダクションバックエンドと同じインターフェース
let store: any KeyValueStore = InMemoryKeyValueStore()
let secrets: any SecureStore = InMemorySecureStore()
let docs: any DocumentStore = InMemoryDocumentStore<Note>()
let registry: any RegistryStore = InMemoryRegistryStore<ModelRecord>()
let fs: any FileSystemReading & FileSystemWriting = InMemoryFileSystem()
let resolver: any KeyResolver = InMemoryKeyResolver(["API_KEY": "test-key-abc"])
```

各ダブルはプロダクション版の挙動に合わせる: `InMemoryKeyValueStore` と `InMemorySecureStore` は値を `JSONEncoder`/`JSONDecoder` でラウンドトリップし、`InMemoryDocumentStore` は存在しない ID に対して ``PersistenceError/notFound(key:)`` をスローし、`InMemoryFileSystem` は初回書き込み時に先祖ディレクトリツリーを自動構築する。

### シードデータの事前設定

`InMemoryFileSystem` 以外の全ダブルにはシード用のコンビニエンスイニシャライザがある:

```swift
// 複数の型を混在させてキーバリューストアを事前設定
let kvStore = InMemoryKeyValueStore(["theme": "dark", "fontSize": 16])

// レジストリを事前設定
let regStore = InMemoryRegistryStore(["llama-3b": ModelRecord(downloadedAt: .now, sizeBytes: 1_800_000_000)])

// API キー注入用の固定リゾルバ
let resolver = InMemoryKeyResolver(["OPENAI_API_KEY": "sk-test-abc"])
```

`InMemoryFileSystem` はテスト対象のシステムが実行される前に `addFile` と `addDirectory` メソッドでプログラム的に構築する:

```swift
let fs = InMemoryFileSystem()

// ツリーを構築
let root = URL(fileURLWithPath: "/skills")
await fs.addFile(root.appendingPathComponent("writing/SKILL.md"), string: "# Writing\n")
await fs.addFile(root.appendingPathComponent("coding/SKILL.md"), string: "# Coding\n")

// テスト対象のシステムがディスクに触れることなくツリーを走査する
let items = try await fs.contentsOfDirectory(root)
```

### アサーションヘルパー

`InMemoryKeyValueStore`・`InMemorySecureStore`・`InMemoryDocumentStore`・`InMemoryRegistryStore` はそれぞれ簡潔な XCTest アサーション用の `count` プロパティを持つ:

```swift
let store = InMemoryDocumentStore<Note>()
try await store.save(Note(id: UUID(), title: "Draft", body: ""))
let count = await store.count
XCTAssertEqual(count, 1)
```

## Topics

### キーバリュー・セキュアストレージダブル

- ``InMemoryKeyValueStore``
- ``InMemorySecureStore``

### ドキュメント・レジストリストレージダブル

- ``InMemoryDocumentStore``
- ``InMemoryRegistryStore``

### ファイルシステムダブル

- ``InMemoryFileSystem``

### キー解決ダブル

- ``InMemoryKeyResolver``
