import Testing
import Foundation
import PersistenceCore
import PersistenceTesting

@Suite("InMemoryFileSystem write")
struct InMemoryFileSystemWritingTests {

    private func url(_ path: String) -> URL { URL(fileURLWithPath: path) }

    @Test("write creates the file and its ancestor directories")
    func writeCreatesAncestors() async throws {
        let fs = InMemoryFileSystem()
        try await fs.write("hello", to: url("/root/skills/pdf/SKILL.md"))

        #expect(await fs.exists(url("/root/skills/pdf/SKILL.md")))
        #expect(try await fs.readString(url("/root/skills/pdf/SKILL.md")) == "hello")
        #expect(await fs.isDirectory(url("/root/skills/pdf")))
        #expect(await fs.isDirectory(url("/root/skills")))
        #expect(await fs.isDirectory(url("/root")))
    }

    @Test("write overwrites an existing file")
    func writeOverwrites() async throws {
        let fs = InMemoryFileSystem()
        try await fs.write("v1", to: url("/r/a.md"))
        try await fs.write("v2", to: url("/r/a.md"))
        #expect(try await fs.readString(url("/r/a.md")) == "v2")
    }

    @Test("createDirectory is idempotent and creates intermediates")
    func createDirectory() async throws {
        let fs = InMemoryFileSystem()
        try await fs.createDirectory(url("/r/a/b"))
        try await fs.createDirectory(url("/r/a/b")) // no throw on re-create
        #expect(await fs.isDirectory(url("/r/a/b")))
        #expect(await fs.isDirectory(url("/r/a")))
    }

    @Test("removeItem deletes a file")
    func removeFile() async throws {
        let fs = InMemoryFileSystem()
        try await fs.write("x", to: url("/r/a.md"))
        try await fs.removeItem(url("/r/a.md"))
        #expect(await fs.exists(url("/r/a.md")) == false)
    }

    @Test("removeItem deletes a directory recursively")
    func removeDirectoryRecursive() async throws {
        let fs = InMemoryFileSystem()
        try await fs.write("a", to: url("/r/skill/SKILL.md"))
        try await fs.write("b", to: url("/r/skill/scripts/run.sh"))
        try await fs.removeItem(url("/r/skill"))

        #expect(await fs.exists(url("/r/skill")) == false)
        #expect(await fs.exists(url("/r/skill/SKILL.md")) == false)
        #expect(await fs.exists(url("/r/skill/scripts/run.sh")) == false)
        #expect(await fs.isDirectory(url("/r"))) // parent survives
    }

    @Test("removeItem on a missing path is a no-op")
    func removeMissingNoop() async throws {
        let fs = InMemoryFileSystem()
        try await fs.removeItem(url("/nope")) // must not throw
    }

    @Test("moveItem renames a directory, preserving its subtree")
    func moveDirectory() async throws {
        let fs = InMemoryFileSystem()
        try await fs.write("a", to: url("/r/old/SKILL.md"))
        try await fs.write("b", to: url("/r/old/scripts/run.sh"))

        try await fs.moveItem(from: url("/r/old"), to: url("/r/new"))

        #expect(await fs.exists(url("/r/old")) == false)
        #expect(await fs.exists(url("/r/old/SKILL.md")) == false)
        #expect(try await fs.readString(url("/r/new/SKILL.md")) == "a")
        #expect(try await fs.readString(url("/r/new/scripts/run.sh")) == "b")
        #expect(await fs.isDirectory(url("/r/new")))
    }

    @Test("moveItem throws notFound when source is absent")
    func moveMissingSource() async throws {
        let fs = InMemoryFileSystem()
        await #expect(throws: PersistenceError.self) {
            try await fs.moveItem(from: url("/r/absent"), to: url("/r/new"))
        }
    }

    @Test("moveItem throws when destination already exists")
    func moveDestinationExists() async throws {
        let fs = InMemoryFileSystem()
        try await fs.write("a", to: url("/r/old/SKILL.md"))
        try await fs.write("b", to: url("/r/new/SKILL.md"))
        await #expect(throws: PersistenceError.self) {
            try await fs.moveItem(from: url("/r/old"), to: url("/r/new"))
        }
    }
}
