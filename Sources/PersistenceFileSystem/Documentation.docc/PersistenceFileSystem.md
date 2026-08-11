# ``PersistenceFileSystem``

Disk-backed persistence for individual documents, single-file registries, and raw file trees.

## Overview

`PersistenceFileSystem` provides three concrete types that together cover the most common ways an app persists data to the local file system.

### Document store

`FileSystemDocumentStore` persists each `Identifiable & Codable` document as its own `{id}.json` file inside a directory you choose. Writes are atomic, so a failed write cannot corrupt an existing file, and the directory is created when you initialise the store. Reach for it when you have a collection of independently readable records — user profiles, notes, cached model metadata — that needs CRUD on disk:

```swift
import Foundation
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

// Read one or all
let loaded = try await store.load(id: note.id)
let all: [Note] = try await store.loadAll()

// Delete
try await store.delete(id: note.id)
```

### Registry store

`FileSystemRegistryStore` persists an entire `[String: Codable]` dictionary to a single JSON file, writing atomically. It is built for the registry pattern, where string keys map to small metadata entries such as download records, cache manifests, or adapter indexes:

```swift
import Foundation
import PersistenceFileSystem

struct ModelRecord: Codable, Sendable {
    var downloadedAt: Date
    var sizeBytes: Int
}

let registry = FileSystemRegistryStore<ModelRecord>(
    directory: URL.cachesDirectory.appendingPathComponent("models")
)

// The calling actor holds the dictionary and saves it after each update
var entries = await registry.load()
entries["llama-3b"] = ModelRecord(downloadedAt: .now, sizeBytes: 1_800_000_000)
try await registry.save(entries)
```

### File system

`FoundationFileSystem` wraps `FileManager` and conforms to both ``FileSystemReading`` and ``FileSystemWriting``. Unlike `FileSystemDocumentStore` and `FileSystemRegistryStore`, it works at the raw file-tree level: checking existence, listing directory contents, reading arbitrary `Data`, creating directories, writing atomically, deleting, and moving. Use it when you need to walk or generate a tree of files rather than handle typed documents:

```swift
import Foundation
import PersistenceFileSystem

let fs = FoundationFileSystem()
let root = URL.documentsDirectory.appendingPathComponent("skills")

// Walking the tree
let items = try await fs.contentsOfDirectory(root)
for item in items where await fs.isDirectory(item) {
    let markdown = try await fs.readString(item.appendingPathComponent("README.md"))
    // Process markdown…
}

// Generating files
let dest = root.appendingPathComponent("new-skill/SKILL.md")
try await fs.write("# New Skill\n", to: dest)   // Parent directories are created for you
```

In test targets, replace all three types with `InMemoryDocumentStore`, `InMemoryRegistryStore`, and `InMemoryFileSystem` from `PersistenceTesting`. Each in-memory double conforms to the same protocols as its file-backed counterpart, so production code does not change.

## Topics

### Document and Registry Storage

- ``FileSystemDocumentStore``
- ``FileSystemRegistryStore``

### File System

- ``FoundationFileSystem``
