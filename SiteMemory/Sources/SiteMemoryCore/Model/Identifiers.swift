import Foundation

/// A strongly-typed identifier.
///
/// Using a phantom type (`ID<Wall>` vs `ID<SitePhoto>`) means the compiler
/// rejects passing a photo id where a wall id is expected — cheap safety that
/// matters once entities cross module and persistence boundaries.
public struct ID<Entity>: Hashable, Codable, CustomStringConvertible, Sendable {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue.uuidString }

    // Encode as a bare UUID string so persisted JSON stays human-readable and
    // is not coupled to the phantom type.
    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(UUID.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Something that carries a typed identity.
public protocol Identifiable2 {
    associatedtype Entity
    var id: ID<Entity> { get }
}
