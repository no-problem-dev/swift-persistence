import Foundation

/// 全永続化操作の統一エラー型。
public enum PersistenceError: Error, Sendable, Equatable {

    /// 要求されたアイテムが見つからない。
    case notFound(key: String)

    /// ストレージ用のエンコードに失敗した。
    case encodingFailed(key: String, reason: String)

    /// 格納データのデコードに失敗した。
    case decodingFailed(key: String, reason: String)

    /// 基礎ストレージ操作が失敗した（ディスク・Keychain など）。
    case storageFailed(operation: String, reason: String)

    /// ストレージへのアクセスが拒否された（例: Keychain エンタイトルメント不足）。
    case accessDenied(reason: String)

    /// ストレージディレクトリを作成できなかった。
    case directoryCreationFailed(path: String, reason: String)
}

// MARK: - LocalizedError

extension PersistenceError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .notFound(let key):
            return "Item not found for key '\(key)'."
        case .encodingFailed(let key, let reason):
            return "Encoding failed for key '\(key)': \(reason)"
        case .decodingFailed(let key, let reason):
            return "Decoding failed for key '\(key)': \(reason)"
        case .storageFailed(let operation, let reason):
            return "Storage operation '\(operation)' failed: \(reason)"
        case .accessDenied(let reason):
            return "Storage access denied: \(reason)"
        case .directoryCreationFailed(let path, let reason):
            return "Could not create directory at '\(path)': \(reason)"
        }
    }
}
