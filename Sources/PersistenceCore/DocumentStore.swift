import Foundation

/// ID を持つ `Codable` ドキュメントのファイルベース CRUD ストレージ。
///
/// ドキュメントは 1 件ずつ（例: `{id}.json`）永続化され、
/// ID による読み込み・保存・一覧取得・削除ができる。
///
/// 実装はファイル I/O を呼び出し元アクターから切り離せるよう `async` メソッドを採用する。
///
/// 実装: ``FileSystemDocumentStore``, ``InMemoryDocumentStore``。
public protocol DocumentStore<Document>: Sendable {
    associatedtype Document: Codable & Identifiable & Sendable
        where Document.ID: CustomStringConvertible & Sendable

    /// ドキュメントを保存する。既存の場合は上書き。
    func save(_ document: Document) async throws

    /// ID を指定してドキュメントを 1 件読み込む。
    ///
    /// - Throws: 該当 ID のドキュメントが存在しない場合は ``PersistenceError/notFound(key:)``。
    func load(id: Document.ID) async throws -> Document

    /// 全ドキュメントを読み込む。
    ///
    /// ドキュメントが 1 件もない場合は空配列を返す。
    func loadAll() async throws -> [Document]

    /// ID を指定してドキュメントを削除する。
    ///
    /// - Throws: 該当 ID のドキュメントが存在しない場合は ``PersistenceError/notFound(key:)``。
    func delete(id: Document.ID) async throws

    /// 指定 ID のドキュメントが存在する場合に `true` を返す。
    func exists(id: Document.ID) async -> Bool
}
