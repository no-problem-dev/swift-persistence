import Foundation
import PersistenceCore

/// テスト用のインメモリ ``DocumentStore``。
///
/// アクター分離によりロック同期を置き換える。
/// ドキュメントは ID をキーとする辞書に格納する。
public actor InMemoryDocumentStore<T: Codable & Identifiable & Sendable>: DocumentStore
    where T.ID: CustomStringConvertible & Hashable & Sendable
{
    public typealias Document = T

    private var documents: [T.ID: T] = [:]

    public init() {}

    public func save(_ document: T) throws {
        documents[document.id] = document
    }

    public func load(id: T.ID) throws -> T {
        guard let document = documents[id] else {
            throw PersistenceError.notFound(key: "\(id)")
        }
        return document
    }

    public func loadAll() throws -> [T] {
        Array(documents.values)
    }

    public func delete(id: T.ID) throws {
        guard documents.removeValue(forKey: id) != nil else {
            throw PersistenceError.notFound(key: "\(id)")
        }
    }

    public func exists(id: T.ID) -> Bool {
        documents[id] != nil
    }

    /// 格納ドキュメント数（テストアサーション用）。
    public var count: Int {
        documents.count
    }
}
