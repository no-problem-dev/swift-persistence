import Foundation
import PersistenceCore

/// 個別の JSON ファイルでドキュメントを永続化する ``DocumentStore`` 実装。
///
/// ドキュメントは設定ディレクトリ内の `{id}.json` として保存される。
/// 全ファイル書き込みはアトミックで、データ破損を防ぐ。
///
/// アクターとして実装することで、ファイル I/O を
/// 呼び出し元アクター（例: `@MainActor`）からアクターホップで自動的に切り離す。
public actor FileSystemDocumentStore<T: Codable & Identifiable & Sendable>: DocumentStore
    where T.ID: CustomStringConvertible & Sendable
{
    public typealias Document = T

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// ファイルシステムドキュメントストアを生成する。
    ///
    /// - Parameters:
    ///   - directory: ドキュメントファイルを格納するディレクトリ。存在しない場合は作成する。
    ///   - encoder: カスタム JSON エンコーダー。デフォルトは ISO 8601 日付・プリティプリント・ソートキー。
    ///   - decoder: カスタム JSON デコーダー。デフォルトは ISO 8601 日付。
    /// - Throws: ディレクトリを作成できない場合は ``PersistenceError/directoryCreationFailed(path:reason:)``。
    public init(
        directory: URL,
        encoder: JSONEncoder? = nil,
        decoder: JSONDecoder? = nil
    ) throws {
        self.directory = directory

        if let encoder {
            self.encoder = encoder
        } else {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            self.encoder = enc
        }

        if let decoder {
            self.decoder = decoder
        } else {
            let dec = JSONDecoder()
            dec.dateDecodingStrategy = .iso8601
            self.decoder = dec
        }

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw PersistenceError.directoryCreationFailed(
                path: directory.path,
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - DocumentStore

    public func save(_ document: T) throws {
        let url = fileURL(for: document.id)
        let data: Data
        do {
            data = try encoder.encode(document)
        } catch {
            throw PersistenceError.encodingFailed(
                key: "\(document.id)",
                reason: error.localizedDescription
            )
        }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw PersistenceError.storageFailed(
                operation: "save",
                reason: error.localizedDescription
            )
        }
    }

    public func load(id: T.ID) throws -> T {
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PersistenceError.notFound(key: "\(id)")
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw PersistenceError.storageFailed(
                operation: "load",
                reason: error.localizedDescription
            )
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw PersistenceError.decodingFailed(
                key: "\(id)",
                reason: error.localizedDescription
            )
        }
    }

    public func loadAll() throws -> [T] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ).filter { $0.pathExtension == "json" }
        } catch {
            throw PersistenceError.storageFailed(
                operation: "loadAll",
                reason: error.localizedDescription
            )
        }

        var documents: [T] = []
        for url in files {
            if let data = try? Data(contentsOf: url),
               let document = try? decoder.decode(T.self, from: data) {
                documents.append(document)
            }
        }
        return documents
    }

    public func delete(id: T.ID) throws {
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PersistenceError.notFound(key: "\(id)")
        }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw PersistenceError.storageFailed(
                operation: "delete",
                reason: error.localizedDescription
            )
        }
    }

    public func exists(id: T.ID) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: id).path)
    }

    // MARK: - Private

    private func fileURL(for id: T.ID) -> URL {
        directory.appendingPathComponent("\(id).json")
    }
}
