# ``PersistenceFileSystem``

ディスク永続化のための ``DocumentStore``・``RegistryStore``・``FileSystemReading``/``FileSystemWriting`` 実装。

## Overview

`PersistenceFileSystem` はローカルファイルシステムへのデータ永続化として最も一般的なパターンをカバーする 3 つの具体型を提供する。

### ドキュメントストア

`FileSystemDocumentStore` は各 `Identifiable & Codable` ドキュメントを設定ディレクトリ内の独立した `{id}.json` ファイルとして永続化する。書き込みはアトミックで破損を防ぎ、ディレクトリは初回使用時に自動作成する。ユーザープロフィール・ノート・キャッシュ済みモデルメタデータなど、独立して読み込めるレコードのコレクションにディスク上での CRUD が必要な場合に適している:

```swift
import PersistenceFileSystem

struct Note: Codable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var body: String
}

let store = try FileSystemDocumentStore<Note>(
    directory: URL.documentsDirectory.appendingPathComponent("notes")
)

// 作成または上書き
let note = Note(id: UUID(), title: "ミーティングノート", body: "…")
try await store.save(note)

// 1 件または全件読み込み
let loaded = try await store.load(id: note.id)
let all: [Note] = try await store.loadAll()

// 削除
try await store.delete(id: note.id)
```

### レジストリストア

`FileSystemRegistryStore` は `[String: Codable]` 辞書全体をアトミック書き込みで単一 JSON ファイルに永続化する。文字列キーをダウンロード記録・キャッシュマニフェスト・アダプタインデックスなどの軽量メタデータエントリにマッピングするレジストリパターン向けの設計:

```swift
import PersistenceFileSystem

struct ModelRecord: Codable, Sendable {
    var downloadedAt: Date
    var sizeBytes: Int
}

let registry = FileSystemRegistryStore<ModelRecord>(
    directory: URL.cachesDirectory.appendingPathComponent("models")
)

// 消費側アクターが辞書を保持し、更新後に save を呼ぶ
var entries = await registry.load()
entries["llama-3b"] = ModelRecord(downloadedAt: .now, sizeBytes: 1_800_000_000)
try await registry.save(entries)
```

### ファイルシステム

`FoundationFileSystem` は `FileManager` をラップし ``FileSystemReading`` と ``FileSystemWriting`` の両方に準拠する。`FileSystemDocumentStore` や `FileSystemRegistryStore` と異なり、生のファイルツリーレベルで動作する — 存在確認・ディレクトリ内容一覧・任意の `Data` 読み込み・ディレクトリ作成・アトミック書き込み・削除・移動。型付きドキュメントを扱うのではなく、ファイルのツリーを走査・生成する必要がある場合に使用する:

```swift
import PersistenceFileSystem

let fs = FoundationFileSystem()
let root = URL.documentsDirectory.appendingPathComponent("skills")

// 読み取り側の走査
let items = try await fs.contentsOfDirectory(root)
for item in items where await fs.isDirectory(item) {
    let markdown = try await fs.readString(item.appendingPathComponent("README.md"))
    // markdown を処理…
}

// 書き込み側の生成
let dest = root.appendingPathComponent("new-skill/SKILL.md")
try await fs.write("# New Skill\n", to: dest)   // 親ディレクトリは自動作成
```

テストターゲットでは、`PersistenceTesting` の `InMemoryDocumentStore`・`InMemoryRegistryStore`・`InMemoryFileSystem` で 3 つの型を全て置き換える。各インメモリダブルはファイルバックド版と同じプロトコルに準拠するため、プロダクションコードの変更は不要。

## Topics

### ドキュメント・レジストリストレージ

- ``FileSystemDocumentStore``
- ``FileSystemRegistryStore``

### ファイルシステム

- ``FoundationFileSystem``
