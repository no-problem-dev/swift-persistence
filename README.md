[English](README_EN.md) | 日本語

# SwiftPersistence

プロトコル指向の永続化抽象レイヤー Swift パッケージ

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 特徴

- **プロトコル指向** - 全永続化操作を抽象プロトコルで定義、DI でテスト容易な設計
- **KeyValueStore** - UserDefaults の型安全な抽象化（Codable 対応）
- **SecureStore** - Keychain の安全なラッパー（API キー・認証情報の保護）
- **DocumentStore** - ファイルベース CRUD（JSON 個別ファイル、atomic write）
- **RegistryStore** - 単一 JSON ファイルによるレジストリパターン
- **KeyResolver** - Info.plist → Keychain → UserDefaults の多段フォールバック値解決
- **テスト用 InMemory 実装** - 全プロトコルの InMemory 実装をバンドル

## インストール

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-persistence.git", .upToNextMajor(from: "1.0.0"))
]
```

### モジュール構成

用途に応じて必要なモジュールのみをインポートできます：

| モジュール | 用途 |
|-----------|------|
| `PersistenceCore` | プロトコル + エラー型（Foundation のみ、外部依存なし） |
| `PersistenceUserDefaults` | UserDefaults ベースの KeyValueStore 実装 |
| `PersistenceKeychain` | Keychain ベースの SecureStore 実装 |
| `PersistenceFileSystem` | ファイルベースの DocumentStore / RegistryStore 実装 |
| `PersistenceTesting` | InMemory 実装 5 種（テスト用 DI） |

## クイックスタート

### キーバリューストア（UserDefaults 抽象）

```swift
import PersistenceUserDefaults

let store = UserDefaultsKeyValueStore()

// Codable 値の保存・取得
try store.setValue("dark", forKey: "theme")
let theme: String? = try store.string(forKey: "theme")

// カスタム型も対応
struct UserPrefs: Codable, Sendable {
    var fontSize: Int
    var language: String
}
try store.setValue(UserPrefs(fontSize: 14, language: "ja"), forKey: "prefs")
let prefs: UserPrefs? = try store.value(forKey: "prefs", type: UserPrefs.self)
```

### セキュアストア（Keychain 抽象）

```swift
import PersistenceKeychain

let secrets = KeychainSecureStore(service: "com.example.myapp")

// API キーを安全に保存
try secrets.setString("sk-abc123...", forKey: "api_key")
let key = try secrets.getString(forKey: "api_key")
```

### ドキュメントストア（ファイルベース CRUD）

```swift
import PersistenceFileSystem

struct Note: Codable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var body: String
}

let store = try FileSystemDocumentStore<Note>(
    directory: documentsURL.appendingPathComponent("notes")
)

// CRUD 操作
let note = Note(id: UUID(), title: "メモ", body: "内容")
try store.save(note)
let all = try store.loadAll()
try store.delete(id: note.id)
```

### レジストリストア（単一 JSON レジストリ）

```swift
import PersistenceFileSystem

struct CacheEntry: Codable, Sendable {
    let version: String
    let downloadedAt: Date
}

let registry = FileSystemRegistryStore<CacheEntry>(
    directory: cacheURL,
    filename: "registry.json"
)

var entries = registry.load()
entries["model-v1"] = CacheEntry(version: "1.0", downloadedAt: Date())
try registry.save(entries)
```

### 多段フォールバック値解決

```swift
import PersistenceCore
import PersistenceKeychain
import PersistenceUserDefaults

let resolver = ChainedKeyResolver(
    secureStore: KeychainSecureStore(service: "com.example.myapp"),
    keyValueStore: UserDefaultsKeyValueStore(),
    keyMapping: [
        "API_KEY": .init(secure: "api_key", keyValue: "api_key"),
    ]
)

// Info.plist → Keychain → UserDefaults の順に探索
let apiKey = resolver.resolve("API_KEY")
```

### テスト用 InMemory 実装

```swift
import PersistenceTesting

// テストで DI 注入
let mockStore = InMemoryKeyValueStore()
let mockSecrets = InMemorySecureStore()
let mockDocs = InMemoryDocumentStore<Note>()

let settings = AppSettings(
    preferences: mockStore,
    secrets: mockSecrets,
    keyResolver: InMemoryKeyResolver(values: ["API_KEY": "test-key"])
)
```

## アーキテクチャ

2 層構造で関心の分離を実現しています：

```
Layer 0: PersistenceCore           プロトコル + エラー型（外部依存なし）
Layer 1: PersistenceUserDefaults   UserDefaults 具象実装
         PersistenceKeychain       Keychain 具象実装
         PersistenceFileSystem     ファイルシステム具象実装
         PersistenceTesting        InMemory テストダブル
```

## 要件

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+
- Xcode 16.0+

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

## リンク

- [Issue報告](https://github.com/no-problem-dev/swift-persistence/issues)
- [ディスカッション](https://github.com/no-problem-dev/swift-persistence/discussions)
