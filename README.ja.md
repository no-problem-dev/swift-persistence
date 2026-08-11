[English](./README.md) | 日本語

# SwiftPersistence

アプリのデータを、どこに保存されるかによらず 1 つのプロトコル越しに読み書きする。ユースケースを UserDefaults にも Keychain にもディスクにも触らずにテストできる。

![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2017.0+%20%7C%20macOS%2014.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

ドメイン層・ユースケース層はプロトコルにだけ依存し、それを `UserDefaults` で満たすのか、
Keychain なのか、ファイルなのか、何も持たないのかは合成ルートが決めます。

## 特徴

- **プロトコル指向** — 永続化の操作をすべて抽象プロトコルで定義するので、ディスクにも Keychain にも
  エンタイトルメントにも触れずにユースケースをテストできます
- **KeyValueStore** — `UserDefaults` の型安全な抽象化。プリミティブはネイティブのアクセサを使い、
  それ以外の `Codable` 型は自動で JSON に変換します
- **SecureStore** — API キーや認証情報のための Keychain ラッパー。アクセシビリティは明示指定で、
  既定はこの端末のみ
- **DocumentStore** — ファイルベースの CRUD。ドキュメント 1 件が JSON ファイル 1 つで、書き込みは atomic
- **RegistryStore** — `[String: Codable]` 辞書ごと単一 JSON ファイルに保存。キャッシュやメタデータの索引向け
- **KeyResolver** — `Info.plist` → Keychain → `UserDefaults` の順で多段フォールバック
- **全プロトコルのインメモリ実装** — シード可能・アクター分離済み。専用モジュールに分けてあるので
  製品ターゲットに混入しません

## クイックスタート

```swift
import PersistenceUserDefaults

let store = UserDefaultsKeyValueStore()

try await store.setValue("dark", forKey: "theme")
let theme: String? = try await store.string(forKey: "theme")
```

バックエンドではなくプロトコルに依存させれば、同じコードがアプリでは本物のストアに、
テストではインメモリのダブルに向きます。

```swift
import PersistenceCore
import PersistenceTesting

let store: any KeyValueStore = InMemoryKeyValueStore(["theme": "dark"])
```

## ドキュメント

[**API リファレンスとガイド**](https://no-problem-dev.github.io/swift-persistence/documentation/persistencecore/) —
[Getting Started](https://no-problem-dev.github.io/swift-persistence/documentation/persistencecore/gettingstarted/) と
[Architecture](https://no-problem-dev.github.io/swift-persistence/documentation/persistencecore/architecture/) を含みます。
各バックエンドが耐久性・スレッド安全性・デコード失敗時の挙動について何を保証するかは Architecture にあります。

## 導入

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-persistence.git", .upToNextMajor(from: "2.0.0"))
]
```

ターゲットが実際に使うモジュールだけを足します。

```swift
.product(name: "PersistenceCore",         package: "swift-persistence"),
.product(name: "PersistenceUserDefaults", package: "swift-persistence"),
.product(name: "PersistenceKeychain",     package: "swift-persistence"),
.product(name: "PersistenceFileSystem",   package: "swift-persistence"),
.product(name: "PersistenceTesting",      package: "swift-persistence"),  // テストターゲットのみ
```

## 動作環境

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+
- Xcode 16.0+

## ライセンス

MIT — [LICENSE](LICENSE) を参照してください。
