import Foundation
import PersistenceCore

/// テスト用のインメモリ ``KeyResolver``。
///
/// 事前設定した辞書から値を返す。
public struct InMemoryKeyResolver: KeyResolver, Sendable {

    private let values: [String: String]

    /// 固定キーバリューペアでリゾルバを生成する。
    public init(_ values: [String: String] = [:]) {
        self.values = values
    }

    public func resolve(_ key: String) async -> String? {
        values[key]
    }
}
