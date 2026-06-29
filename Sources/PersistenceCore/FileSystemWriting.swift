import Foundation

/// 書き込み側ファイルシステム抽象 — ``FileSystemReading`` の対。
///
/// `FileManager` に依存せず、ディレクトリ作成・ファイル書き込み・
/// 削除・移動を抽象化する。消費側コード（例: スキルルート下の `SKILL.md` 生成）を
/// テスト容易にし、サンドボックスやリモートバックエンドへの差し替えを可能にする。
///
/// ``FileSystemReading`` と組み合わせて、単一バックエンド
/// （ディスクは ``FoundationFileSystem``、テストは ``InMemoryFileSystem``）が
/// 読み書き両方に対応する。
///
/// 実装は I/O を呼び出し元アクターから切り離せるよう `async` メソッドを採用する。
///
/// 実装: ``FoundationFileSystem``, ``InMemoryFileSystem``。
public protocol FileSystemWriting: Sendable {

    /// 指定 URL にディレクトリを作成する。中間ディレクトリも必要に応じて生成。
    ///
    /// 冪等: ディレクトリが既に存在する場合もエラーにならない。
    ///
    /// - Throws: ディレクトリを作成できない場合は ``PersistenceError/directoryCreationFailed(path:reason:)``。
    func createDirectory(_ url: URL) async throws

    /// 指定 URL のファイルに `data` をアトミックに書き込む。既存ファイルは上書き。
    ///
    /// 親ディレクトリが存在しない場合も自動的に作成するため、
    /// 1 回の `write` だけで新規パスへのファイル生成が完結する。
    ///
    /// - Throws: 書き込みエラーは ``PersistenceError/storageFailed(operation:reason:)``。
    func write(_ data: Data, to url: URL) async throws

    /// 指定 URL のファイルまたはディレクトリを再帰的に削除する。
    ///
    /// 冪等: 指定 URL に何も存在しない場合もエラーにならない。
    ///
    /// - Throws: 削除エラーは ``PersistenceError/storageFailed(operation:reason:)``。
    func removeItem(_ url: URL) async throws

    /// `source` のファイルまたはディレクトリをサブツリーごと `destination` に移動する。
    ///
    /// - Throws: `source` が存在しない場合は ``PersistenceError/notFound(key:)``。
    ///   `destination` が既に存在するか移動が失敗した場合は ``PersistenceError/storageFailed(operation:reason:)``。
    func moveItem(from source: URL, to destination: URL) async throws
}

extension FileSystemWriting {

    /// 指定 URL のファイルに文字列を UTF-8 で書き込む。
    public func write(_ string: String, to url: URL) async throws {
        try await write(Data(string.utf8), to: url)
    }
}
