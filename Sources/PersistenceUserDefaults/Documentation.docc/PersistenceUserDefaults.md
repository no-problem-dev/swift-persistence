# ``PersistenceUserDefaults``

軽量なユーザー設定保存のための `UserDefaults` バックド ``KeyValueStore`` 実装。

## Overview

`PersistenceUserDefaults` は、アプリ起動をまたいで永続化するが暗号化が不要な設定 — テーマ選択・フィーチャーフラグ・チュートリアル進捗・同様の軽量な状態 — を `UserDefaults` に保存する具体的な ``KeyValueStore`` である `UserDefaultsKeyValueStore` を提供する。

`UserDefaultsKeyValueStore` はアクターなので読み書きが呼び出し元アクターから自動的にホップし、メインスレッドをブロックせず `@MainActor` のビューモデルから安全に呼び出せる。

プリミティブ型（`String`、`Bool`、`Int`、`Double`、`Data`）は `UserDefaults` のネイティブアクセサを効率的に使用する。それ以外の `Codable` 型は `JSONEncoder`/`JSONDecoder` で透過的に変換する:

```swift
import PersistenceUserDefaults

let store = UserDefaultsKeyValueStore()

// プリミティブ値を書き込む
try await store.setValue(true, forKey: "notifications_enabled")

// 型付きコンビニエンスアクセサで読み込む
let enabled: Bool? = try await store.bool(forKey: "notifications_enabled")

// カスタム Codable 型 — 自動的に JSON エンコード
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

共有コンテナ（App Groups）には初期化時に `suiteName` を渡す:

```swift
let sharedStore = UserDefaultsKeyValueStore(suiteName: "group.com.example.app")
```

テストターゲットでは、`PersistenceTesting` の `InMemoryKeyValueStore` で `UserDefaultsKeyValueStore` を置き換える。両者とも ``KeyValueStore`` に準拠するため、プロダクションコードの変更は不要。

## Topics

### 実装

- ``UserDefaultsKeyValueStore``
