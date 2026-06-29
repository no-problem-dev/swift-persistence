# ``PersistenceKeychain``

暗号化されたクレデンシャル・シークレット保存のための ``SecureStore`` 実装。

## Overview

`PersistenceKeychain` は、静止状態で暗号化され・アプリ再インストール後も残す必要がある値 — API キー・OAuth トークン・セッションクレデンシャル・`UserDefaults` やディスクの平文に保存してはいけないシークレット — のための具体的な ``SecureStore`` である `KeychainSecureStore` を提供する。

内部では、各エントリを `kSecClassGenericPassword` Keychain アイテムとして保存し、論理キーを `kSecAttrAccount` 属性に、設定可能なサービス識別子を `kSecAttrService` にマッピングする。全書き込みはアップサート（存在する場合は更新、存在しない場合は追加）なので、同じキーへの `setString` や `setData` の繰り返し呼び出しは安全。

`KeychainSecureStore` はアクターなので Keychain IPC が呼び出し元アクターから自動的に切り離され、`@MainActor` のビューモデルから安全に呼び出せる。

`KeychainAccessibility` ポリシーは Keychain アイテムをいつ読み込めるか・iCloud Keychain に同期するかを制御する。推奨デフォルト — ``KeychainAccessibility/whenUnlockedThisDeviceOnly`` — はデバイスのロック解除中のみアクセスを許可し iCloud 同期を抑制することで Apple Review §2.1 データ保護要件を満たす:

```swift
import PersistenceKeychain

// デフォルト: whenUnlockedThisDeviceOnly — 暗号化・デバイス固有・iCloud 同期なし
let secrets = KeychainSecureStore(
    service: Bundle.main.bundleIdentifier ?? "com.example.app"
)

// API キーを保存
try await secrets.setString("sk-live-abc123", forKey: "openai_api_key")

// 取得
if let apiKey = try await secrets.getString(forKey: "openai_api_key") {
    // apiKey を使用
}

// 削除（例: サインアウト時）
try await secrets.remove(forKey: "openai_api_key")
```

バックグラウンドタスクで必要なクレデンシャル（再起動後の初回ロック解除以降アクセス可能）には `afterFirstUnlockThisDeviceOnly` を使用する。ユーザーのデバイス間で iCloud Keychain 経由でローミングが必要なクレデンシャルには `whenUnlocked` を使用する:

```swift
// バックグラウンドアクセス可能・デバイス固有
let backgroundSecrets = KeychainSecureStore(
    service: "com.example.app",
    accessibility: .afterFirstUnlockThisDeviceOnly
)

// iCloud Keychain 経由でデバイス間ローミング
let cloudSecrets = KeychainSecureStore(
    service: "com.example.app",
    accessibility: .whenUnlocked
)
```

App Group Keychain によるアプリ間共有には `accessGroup` を渡す:

```swift
let sharedSecrets = KeychainSecureStore(
    service: "com.example.app",
    accessGroup: "$(AppIdentifierPrefix)group.com.example.shared"
)
```

テストターゲットでは、`PersistenceTesting` の `InMemorySecureStore` で `KeychainSecureStore` を置き換える。両者とも ``SecureStore`` に準拠するため、テスト時はエンタイトルメントも実 Keychain アクセスも不要。

## Topics

### 実装

- ``KeychainSecureStore``

### アクセシビリティポリシー

- ``KeychainAccessibility``
