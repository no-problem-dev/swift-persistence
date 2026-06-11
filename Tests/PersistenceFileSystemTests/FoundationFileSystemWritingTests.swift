import Testing
import Foundation
import PersistenceCore
import PersistenceFileSystem

@Suite("FoundationFileSystem write")
struct FoundationFileSystemWritingTests {

    /// A unique temp directory removed after the test body runs.
    private func withTempDir(_ body: (URL, FoundationFileSystem) async throws -> Void) async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("fs-write-\(UUID().uuidString)", isDirectory: true)
        let fs = FoundationFileSystem()
        defer { try? FileManager.default.removeItem(at: root) }
        try await body(root, fs)
    }

    @Test("write creates the file and its ancestor directories")
    func writeCreatesAncestors() async throws {
        try await withTempDir { root, fs in
            let skill = root.appendingPathComponent("skills/pdf/SKILL.md")
            try await fs.write("hello", to: skill)

            #expect(await fs.exists(skill))
            #expect(try await fs.readString(skill) == "hello")
            #expect(await fs.isDirectory(root.appendingPathComponent("skills/pdf")))
        }
    }

    @Test("write overwrites an existing file")
    func writeOverwrites() async throws {
        try await withTempDir { root, fs in
            let file = root.appendingPathComponent("a.md")
            try await fs.write("v1", to: file)
            try await fs.write("v2", to: file)
            #expect(try await fs.readString(file) == "v2")
        }
    }

    @Test("createDirectory is idempotent")
    func createDirectory() async throws {
        try await withTempDir { root, fs in
            let dir = root.appendingPathComponent("a/b/c")
            try await fs.createDirectory(dir)
            try await fs.createDirectory(dir)
            #expect(await fs.isDirectory(dir))
        }
    }

    @Test("removeItem deletes a directory recursively and is a no-op when absent")
    func removeRecursiveAndNoop() async throws {
        try await withTempDir { root, fs in
            let skill = root.appendingPathComponent("skill")
            try await fs.write("a", to: skill.appendingPathComponent("SKILL.md"))
            try await fs.write("b", to: skill.appendingPathComponent("scripts/run.sh"))

            try await fs.removeItem(skill)
            #expect(await fs.exists(skill) == false)

            try await fs.removeItem(skill) // no throw on absent
        }
    }

    @Test("moveItem renames a directory preserving its subtree")
    func moveDirectory() async throws {
        try await withTempDir { root, fs in
            let old = root.appendingPathComponent("old")
            let new = root.appendingPathComponent("new")
            try await fs.write("a", to: old.appendingPathComponent("SKILL.md"))
            try await fs.write("b", to: old.appendingPathComponent("scripts/run.sh"))

            try await fs.moveItem(from: old, to: new)

            #expect(await fs.exists(old) == false)
            #expect(try await fs.readString(new.appendingPathComponent("SKILL.md")) == "a")
            #expect(try await fs.readString(new.appendingPathComponent("scripts/run.sh")) == "b")
        }
    }

    @Test("moveItem throws notFound when source is absent")
    func moveMissingSource() async throws {
        try await withTempDir { root, fs in
            await #expect(throws: PersistenceError.self) {
                try await fs.moveItem(from: root.appendingPathComponent("absent"),
                                      to: root.appendingPathComponent("new"))
            }
        }
    }

    @Test("moveItem throws when destination already exists")
    func moveDestinationExists() async throws {
        try await withTempDir { root, fs in
            let old = root.appendingPathComponent("old")
            let new = root.appendingPathComponent("new")
            try await fs.write("a", to: old.appendingPathComponent("SKILL.md"))
            try await fs.write("b", to: new.appendingPathComponent("SKILL.md"))
            await #expect(throws: PersistenceError.self) {
                try await fs.moveItem(from: old, to: new)
            }
        }
    }
}
