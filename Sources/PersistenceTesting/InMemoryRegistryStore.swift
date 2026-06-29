import Foundation
import PersistenceCore

/// テスト用のインメモリ ``RegistryStore``。
///
/// アクター分離によりロック同期を置き換える。
/// JSON レジストリファイルパターンをシミュレートする。
public actor InMemoryRegistryStore<Entry: Codable & Sendable>: RegistryStore {

    private var registry: [String: Entry] = [:]

    public init() {}

    /// 初期状態を持つレジストリストアを生成する。
    public init(_ initial: [String: Entry]) {
        self.registry = initial
    }

    public func load() -> [String: Entry] {
        registry
    }

    public func save(_ registry: [String: Entry]) throws {
        self.registry = registry
    }

    /// エントリ数（テストアサーション用）。
    public var count: Int {
        registry.count
    }
}
