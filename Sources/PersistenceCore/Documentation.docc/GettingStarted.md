# swift-persistence をはじめる

数行のコードで Swift アプリに永続化を追加する。

## Overview

### インストール

`Package.swift` に Swift Package Manager 経由でパッケージを追加する:

```swift
dependencies: [
    .package(
        url: "https://github.com/no-problem-dev/swift-persistence.git",
        from: "1.0.0"
    )
]
```

ターゲットの `dependencies` には必要なモジュールだけを追加する:

| モジュール | 用途 |
|--------|-------------|
| `PersistenceCore` | 常時 — プロトコルと `PersistenceError` |
| `PersistenceUserDefaults` | UserDefaults へのユーザー設定保存 |
| `PersistenceKeychain` | API キー・トークン・クレデンシャルの保存 |
| `PersistenceFileSystem` | ドキュメントやレジストリのディスク保存 |
| `PersistenceTesting` | ユニットテスト用インメモリダブル |

### UserDefaults バックエンド — `UserDefaultsKeyValueStore`

軽量なユーザー設定には `UserDefaultsKeyValueStore` を使用する。プリミティブ型（`String`、`Bool`、`Int`、`Double`、`Data`）はネイティブアクセサを使用し、その他の `Codable` 型は自動的に JSON エンコードする。

```swift
import PersistenceUserDefaults

let store = UserDefaultsKeyValueStore()

// 書き込み
try await store.setValue("dark", forKey: "theme")

// コンビニエンスアクセサで読み込み
let theme: String? = try await store.string(forKey: "theme")

// カスタム Codable 型
struct AppPreferences: Codable, Sendable {
    var fontSize: Int
    var colorScheme: String
}
try await store.setValue(AppPreferences(fontSize: 14, colorScheme: "dark"), forKey: "prefs")
let prefs: AppPreferences? = try await store.value(forKey: "prefs", type: AppPreferences.self)
```

### Keychain バックエンド — `KeychainSecureStore`

API キーやセッショントークンなどの機密値には `KeychainSecureStore` を使用する。アイテムは `kSecClassGenericPassword` として OS により暗号化される。

```swift
import PersistenceKeychain

// デフォルト: whenUnlockedThisDeviceOnly — iCloud 同期なし・デバイス固有
let secrets = KeychainSecureStore(service: Bundle.main.bundleIdentifier ?? "com.example.app")

// API キーを保存
try await secrets.setString("sk-live-abc123", forKey: "openai_api_key")

// 取得
if let apiKey = try await secrets.getString(forKey: "openai_api_key") {
    // apiKey を使用
}

// デバイス間共有が必要な場合は .whenUnlocked を使用
let sharedSecrets = KeychainSecureStore(
    service: "com.example.app",
    accessibility: .whenUnlocked
)
```

### ファイルシステムバックエンド — `FileSystemDocumentStore` と `FoundationFileSystem`

`FileSystemDocumentStore` は各 `Identifiable & Codable` ドキュメントを独立した `{id}.json` ファイルとして永続化する。`FoundationFileSystem` はディレクトリ走査とファイル生成のための生ファイルツリーアクセスを提供する。

```swift
import PersistenceFileSystem

struct Note: Codable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var body: String
}

// 初期セットアップ — ディレクトリが存在しない場合は自動作成
let store = try FileSystemDocumentStore<Note>(
    directory: URL.documentsDirectory.appendingPathComponent("notes")
)

// 作成 / 更新
let note = Note(id: UUID(), title: "ミーティングノート", body: "...")
try await store.save(note)

// 読み込み
let loaded = try await store.load(id: note.id)
let all: [Note] = try await store.loadAll()

// 削除
try await store.delete(id: note.id)
```

### テスト

`PersistenceTesting` のインメモリダブルで全プロダクションバックエンドを置き換える — ディスクや Keychain へのアクセスは不要。

```swift
import PersistenceTesting

// プロトコル型で注入 — 同じコードがどちらのバックエンドでも動作する
let store: any KeyValueStore = InMemoryKeyValueStore()
let secrets: any SecureStore = InMemorySecureStore()
let docs: any DocumentStore = InMemoryDocumentStore<Note>()
let fs: any FileSystemReading & FileSystemWriting = InMemoryFileSystem()

// 決定的なテストのためにシードデータを事前設定
let seeded = InMemoryKeyValueStore(["theme": "dark"])
let fixedResolver = InMemoryKeyResolver(["API_KEY": "test-key-abc"])
```

### エラーハンドリング

全操作は `PersistenceError` をスローする。`LocalizedError` に準拠しているため、`error.localizedDescription` でキーと原因を含む人間が読めるメッセージを取得できる:

```swift
do {
    let value = try await store.value(forKey: "missing", type: String.self)
} catch let error as PersistenceError {
    // error.localizedDescription → "Item not found for key 'missing'."
    print(error.localizedDescription)
}
```
