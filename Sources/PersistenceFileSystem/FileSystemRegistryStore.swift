import Foundation
import PersistenceCore

/// 単一の JSON ファイルでレジストリを永続化する ``RegistryStore`` 実装。
///
/// 文字列キーから `Codable` メタデータエントリへのマッピングを
/// 単一 JSON ファイルで管理するレジストリパターンを汎化する。
/// ファイルの読み書きはアトミックに行う。
///
/// アクターとして実装することで、ファイル I/O を
/// 呼び出し元アクター（例: `@MainActor`）からアクターホップで自動的に切り離す。
public actor FileSystemRegistryStore<Entry: Codable & Sendable>: RegistryStore {

    private let registryURL: URL

    /// ファイル URL 指定でファイルシステムレジストリストアを生成する。
    ///
    /// - Parameter registryURL: JSON レジストリファイルのフルパス。
    public init(registryURL: URL) {
        self.registryURL = registryURL
    }

    /// ディレクトリとファイル名指定でファイルシステムレジストリストアを生成する。
    ///
    /// - Parameters:
    ///   - directory: レジストリファイルを含むディレクトリ。
    ///   - filename: レジストリファイル名。デフォルトは `"registry.json"`。
    public init(directory: URL, filename: String = "registry.json") {
        self.registryURL = directory.appendingPathComponent(filename)
    }

    // MARK: - RegistryStore

    public func load() -> [String: Entry] {
        guard FileManager.default.fileExists(atPath: registryURL.path) else {
            return [:]
        }
        do {
            let data = try Data(contentsOf: registryURL)
            return try JSONDecoder().decode([String: Entry].self, from: data)
        } catch {
            return [:]
        }
    }

    public func save(_ registry: [String: Entry]) throws {
        let directory = registryURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            throw PersistenceError.directoryCreationFailed(
                path: directory.path,
                reason: error.localizedDescription
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(registry)
        } catch {
            throw PersistenceError.encodingFailed(
                key: "registry",
                reason: error.localizedDescription
            )
        }
        do {
            try data.write(to: registryURL, options: .atomic)
        } catch {
            throw PersistenceError.storageFailed(
                operation: "save",
                reason: error.localizedDescription
            )
        }
    }
}
