import Foundation

/// 読み取り専用のファイルシステムツリー走査抽象。
///
/// `FileManager` に依存せず、ディレクトリ走査とファイル読み取りが
/// 必要な消費側コード（例: スキルルート配下の `SKILL.md` 探索）を
/// テスト容易にし、サンドボックスやリモートバックエンドへの差し替えを可能にする。
///
/// ``DocumentStore``（キード CRUD）・``RegistryStore``（単一キードファイル）と異なり、
/// 存在確認・ディレクトリ一覧・バイト読み取りというツリー走査操作をモデル化する。
///
/// 実装は I/O を呼び出し元アクターから切り離せるよう `async` メソッドを採用する。
///
/// 実装: ``FoundationFileSystem``, ``InMemoryFileSystem``。
public protocol FileSystemReading: Sendable {

    /// 指定 URL にファイルまたはディレクトリが存在する場合に `true` を返す。
    func exists(_ url: URL) async -> Bool

    /// 指定 URL にディレクトリが存在する場合に `true` を返す。
    func isDirectory(_ url: URL) async -> Bool

    /// 指定 URL の直下の子要素（ファイルとディレクトリ）を返す。
    ///
    /// - Throws: `url` が存在するディレクトリでない場合は ``PersistenceError/notFound(key:)``。
    ///   基底の読み取りエラーは ``PersistenceError/storageFailed(operation:reason:)``。
    func contentsOfDirectory(_ url: URL) async throws -> [URL]

    /// 指定 URL のファイルの生バイトを読み込む。
    ///
    /// - Throws: ファイルが存在しない場合は ``PersistenceError/notFound(key:)``、
    ///   読み取りエラーは ``PersistenceError/storageFailed(operation:reason:)``。
    func readData(_ url: URL) async throws -> Data
}

extension FileSystemReading {

    /// 指定 URL のファイルを UTF-8 文字列として読み込む。
    public func readString(_ url: URL) async throws -> String {
        let data = try await readData(url)
        guard let string = String(data: data, encoding: .utf8) else {
            throw PersistenceError.decodingFailed(
                key: url.path,
                reason: "File is not valid UTF-8"
            )
        }
        return string
    }
}
