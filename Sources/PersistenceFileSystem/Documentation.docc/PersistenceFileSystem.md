# ``PersistenceFileSystem``

File-system-backed ``DocumentStore``, ``RegistryStore``, and ``FileSystemReading``/``FileSystemWriting`` implementations for disk persistence.

## Overview

`PersistenceFileSystem` provides three concrete types that cover the most common patterns for persisting data to the local file system.

### Document Store

`FileSystemDocumentStore` persists each `Identifiable & Codable` document as a separate `{id}.json` file inside a configured directory. Writes are atomic to prevent corruption, and the directory is created automatically on first use. It is the right choice when you need per-entity CRUD on disk — user profiles, notes, cached model metadata, or any collection of independently loadable records:

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

// Create or overwrite
let note = Note(id: UUID(), title: "Meeting notes", body: "…")
try await store.save(note)

// Load one or all
let loaded = try await store.load(id: note.id)
let all: [Note] = try await store.loadAll()

// Delete
try await store.delete(id: note.id)
```

### Registry Store

`FileSystemRegistryStore` persists an entire `[String: Codable]` dictionary to a single JSON file using atomic writes. It is designed for the registry pattern — a single file that maps string keys to lightweight metadata entries such as download records, cache manifests, or adapter indexes:

```swift
import PersistenceFileSystem

struct ModelRecord: Codable, Sendable {
    var downloadedAt: Date
    var sizeBytes: Int
}

let registry = FileSystemRegistryStore<ModelRecord>(
    directory: URL.cachesDirectory.appendingPathComponent("models")
)

// The consuming actor holds the dictionary and calls save after mutations
var entries = await registry.load()
entries["llama-3b"] = ModelRecord(downloadedAt: .now, sizeBytes: 1_800_000_000)
try await registry.save(entries)
```

### File System

`FoundationFileSystem` wraps `FileManager` and conforms to both ``FileSystemReading`` and ``FileSystemWriting``. Unlike `FileSystemDocumentStore` and `FileSystemRegistryStore`, it operates at the raw file-tree level — checking existence, listing directory contents, reading arbitrary `Data`, creating directories, writing atomically, deleting, and moving items. Use it when your code needs to traverse or author a tree of files rather than work with typed documents:

```swift
import PersistenceFileSystem

let fs = FoundationFileSystem()
let root = URL.documentsDirectory.appendingPathComponent("skills")

// Read-side traversal
let items = try await fs.contentsOfDirectory(root)
for item in items where await fs.isDirectory(item) {
    let markdown = try await fs.readString(item.appendingPathComponent("README.md"))
    // process markdown…
}

// Write-side authoring
let dest = root.appendingPathComponent("new-skill/SKILL.md")
try await fs.write("# New Skill\n", to: dest)   // parent directories created automatically
```

In test targets, replace all three types with `InMemoryDocumentStore`, `InMemoryRegistryStore`, and `InMemoryFileSystem` from `PersistenceTesting`. Each in-memory double conforms to the same protocol as its file-backed counterpart, so no production code needs to change.

## Topics

### Document and Registry Storage

- ``FileSystemDocumentStore``
- ``FileSystemRegistryStore``

### File System

- ``FoundationFileSystem``
