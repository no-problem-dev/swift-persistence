import Testing
import Foundation
import PersistenceCore
import PersistenceTesting

@Suite("InMemoryFileSystem")
struct InMemoryFileSystemTests {

    private func url(_ path: String) -> URL { URL(fileURLWithPath: path) }

    @Test("adding a file registers ancestor directories")
    func ancestors() async throws {
        let fs = InMemoryFileSystem()
        await fs.addFile(url("/root/skills/pdf/SKILL.md"), string: "hi")

        #expect(await fs.exists(url("/root/skills/pdf/SKILL.md")))
        #expect(await fs.isDirectory(url("/root/skills/pdf")))
        #expect(await fs.isDirectory(url("/root/skills")))
        #expect(await fs.isDirectory(url("/root")))
        #expect(await fs.isDirectory(url("/root/skills/pdf/SKILL.md")) == false)
    }

    @Test("contentsOfDirectory returns only immediate children")
    func immediateChildren() async throws {
        let fs = InMemoryFileSystem()
        await fs.addFile(url("/r/a/SKILL.md"), string: "a")
        await fs.addFile(url("/r/b/SKILL.md"), string: "b")
        await fs.addFile(url("/r/note.txt"), string: "n")

        let children = try await fs.contentsOfDirectory(url("/r")).map(\.path).sorted()
        #expect(children == ["/r/a", "/r/b", "/r/note.txt"])

        let aChildren = try await fs.contentsOfDirectory(url("/r/a")).map(\.lastPathComponent)
        #expect(aChildren == ["SKILL.md"])
    }

    @Test("readString round-trips UTF-8")
    func readString() async throws {
        let fs = InMemoryFileSystem()
        await fs.addFile(url("/r/x.md"), string: "héllo 技能")
        #expect(try await fs.readString(url("/r/x.md")) == "héllo 技能")
    }

    @Test("missing reads throw notFound")
    func missing() async throws {
        let fs = InMemoryFileSystem()
        await #expect(throws: PersistenceError.self) {
            try await fs.readData(url("/nope.md"))
        }
        await #expect(throws: PersistenceError.self) {
            try await fs.contentsOfDirectory(url("/nope"))
        }
    }
}
