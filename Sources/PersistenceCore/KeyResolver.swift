import Foundation

/// 複数のソースを優先順位順に試して値を解決するリゾルバ。
///
/// Info.plist → Keychain → UserDefaults の順に設定値を探す
/// 一般的なパターンを抽象化する。
///
/// 実装: ``ChainedKeyResolver``, ``InMemoryKeyResolver``。
public protocol KeyResolver: Sendable {

    /// 指定の論理キーに対して文字列値を解決する。
    ///
    /// - Returns: 解決した値。どのソースにも値がない場合は `nil`。
    func resolve(_ key: String) async -> String?
}

/// Info.plist → SecureStore → KeyValueStore の順に値を解決するリゾルバ。
public struct ChainedKeyResolver: KeyResolver, Sendable {

    private let infoPlistLookup: @Sendable (String) -> String?
    private let secureStore: any SecureStore
    private let keyValueStore: any KeyValueStore

    /// 論理キー名を各ストアでの実ストレージキーにマッピングする辞書。
    ///
    /// 例: `"ANTHROPIC_API_KEY"` → `(secure: "anthropic_api_key", kv: "anthropic_api_key")`
    private let keyMapping: [String: StorageKeys]

    /// 論理キーに対応する各ストアでの実ストレージキーのペア。
    public struct StorageKeys: Sendable {
        public let secure: String
        public let keyValue: String

        public init(secure: String, keyValue: String) {
            self.secure = secure
            self.keyValue = keyValue
        }
    }

    /// チェーンドキーリゾルバを生成する。
    ///
    /// - Parameters:
    ///   - infoPlistLookup: Info.plist から値を参照するクロージャ。
    ///     デフォルトは `Bundle.main.infoDictionary` 参照。
    ///   - secureStore: 2 番目に参照するセキュアストレージ（Keychain）。
    ///   - keyValueStore: 最後に参照するキーバリューストレージ（UserDefaults、マイグレーション用フォールバック）。
    ///   - keyMapping: 論理キー名を各ストアのキーにマッピングする辞書。
    public init(
        infoPlistLookup: @escaping @Sendable (String) -> String? = { key in
            Bundle.main.infoDictionary?[key] as? String
        },
        secureStore: any SecureStore,
        keyValueStore: any KeyValueStore,
        keyMapping: [String: StorageKeys]
    ) {
        self.infoPlistLookup = infoPlistLookup
        self.secureStore = secureStore
        self.keyValueStore = keyValueStore
        self.keyMapping = keyMapping
    }

    public func resolve(_ key: String) async -> String? {
        // 1. Info.plist (xcconfig 経由のビルド時注入)
        if let value = infoPlistLookup(key),
           !value.isEmpty,
           !value.hasPrefix("$(") {
            return value
        }

        guard let mapping = keyMapping[key] else { return nil }

        // 2. SecureStore (Keychain)
        // `try?` は意図的: エンタイトルメント不足や一時的な Keychain エラーは
        // 「このソースに値なし」として扱い、次のソースへグレースフルにフォールスルーさせる。
        if let value = try? await secureStore.getString(forKey: mapping.secure),
           !value.isEmpty {
            return value
        }

        // 3. KeyValueStore (UserDefaults — マイグレーション中のレガシーフォールバック)
        // 同様に意図的な `try?`: 古いエントリのデコードエラーもサイレントにフォールスルー。
        if let value = try? await keyValueStore.string(forKey: mapping.keyValue),
           !value.isEmpty {
            return value
        }

        return nil
    }
}
