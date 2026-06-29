import Foundation

/// セキュアなクレデンシャルストレージ（Keychain）の抽象。
///
/// API キーなどの機密値を暗号化ストレージに保存する。
/// ``KeyValueStore`` と異なり、シークレット・トークンで多用する
/// 文字列とバイナリ値に特化する。
///
/// 実装は I/O を呼び出し元アクターから切り離せるよう `async` メソッドを採用する。
///
/// 実装: ``KeychainSecureStore``, ``InMemorySecureStore``。
public protocol SecureStore: Sendable {

    /// セキュアストレージから文字列値を読み込む。
    ///
    /// - Returns: 格納された文字列。キーが存在しない場合は `nil`。
    func getString(forKey key: String) async throws -> String?

    /// セキュアストレージに文字列値を書き込む。同キーの既存値は上書き。
    func setString(_ value: String, forKey key: String) async throws

    /// セキュアストレージから生バイトを読み込む。
    ///
    /// - Returns: 格納されたデータ。キーが存在しない場合は `nil`。
    func getData(forKey key: String) async throws -> Data?

    /// セキュアストレージに生バイトを書き込む。同キーの既存値は上書き。
    func setData(_ value: Data, forKey key: String) async throws

    /// 指定キーの値を削除する。キーが存在しない場合もエラーにならない。
    func remove(forKey key: String) async throws

    /// 指定キーに値が存在する場合に `true` を返す。
    func contains(key: String) async throws -> Bool
}
