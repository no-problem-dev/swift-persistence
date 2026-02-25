import Foundation
import PersistenceCore

/// In-memory ``KeyResolver`` for testing.
///
/// Returns values from a pre-configured dictionary.
public struct InMemoryKeyResolver: KeyResolver, Sendable {

    private let values: [String: String]

    /// Creates a resolver with fixed key-value pairs.
    public init(_ values: [String: String] = [:]) {
        self.values = values
    }

    public func resolve(_ key: String) -> String? {
        values[key]
    }
}
