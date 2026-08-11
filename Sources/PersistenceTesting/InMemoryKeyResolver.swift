import Foundation
import PersistenceCore

/// Answers from a fixed dictionary given at initialisation, for use in tests.
///
/// It consults nothing else: no bundle, no secure storage, no defaults. Values come back exactly
/// as supplied, empty strings included, where the chained resolver would treat an empty string as
/// absent and carry on down its chain.
public struct InMemoryKeyResolver: KeyResolver, Sendable {

    private let values: [String: String]

    /// Creates a resolver over a fixed set of answers.
    ///
    /// - Parameter values: Every key it will answer. Anything else resolves to `nil`.
    public init(_ values: [String: String] = [:]) {
        self.values = values
    }

    public func resolve(_ key: String) async -> String? {
        values[key]
    }
}
