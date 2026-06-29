import Foundation

/// キー付きエントリの JSON バックドレジストリ。
///
/// 文字列キーからメタデータエントリへのマッピングを
/// 単一 JSON ファイルで管理するパターンを汎化する。
/// モデルキャッシュやアダプタキャッシュのレジストリなどで活用する。
///
/// 消費側コード（通常はアクター）がメモリ内辞書を保持し、
/// 初期化時に `load()` を、更新後に `save(_:)` を呼ぶ。
///
/// 実装は I/O を呼び出し元アクターから切り離せるよう `async` メソッドを採用する。
///
/// 実装: ``FileSystemRegistryStore``, ``InMemoryRegistryStore``。
public protocol RegistryStore<Entry>: Sendable {
    associatedtype Entry: Codable & Sendable

    /// レジストリ全体をストレージから読み込む。
    ///
    /// レジストリが存在しない・デコードできない場合は空辞書を返す。
    func load() async -> [String: Entry]

    /// レジストリ全体をストレージにアトミックに保存する。
    func save(_ registry: [String: Entry]) async throws
}
