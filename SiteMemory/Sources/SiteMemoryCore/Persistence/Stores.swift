import Foundation

/// Persistence is expressed purely as protocols in Core. Concrete stores
/// (file, in-memory, and — when embedded — FieldReport's own database) live in
/// adapter modules. That is what lets SiteMemory reuse the host app's storage
/// when embedded, and bring its own when standalone.

public enum StoreError: Error, Sendable {
    case notFound
    case imageDataUnavailable
    case underlying(String)
}

/// CRUD over the metadata tree. Every method is async so an implementation
/// backed by a database or actor can serialize access without changing callers.
public protocol ProjectStore: Sendable {
    func projects() async throws -> [Project]
    func save(_ project: Project) async throws
    func delete(_ id: ID<Project>) async throws

    func buildings(in project: ID<Project>) async throws -> [Building]
    func floors(in building: ID<Building>) async throws -> [Floor]
    func rooms(in floor: ID<Floor>) async throws -> [Room]
    func walls(in room: ID<Room>) async throws -> [Wall]

    func save(_ building: Building) async throws
    func save(_ floor: Floor) async throws
    func save(_ room: Room) async throws
    func save(_ wall: Wall) async throws
}

/// Stores photo *metadata* and brokers access to the *bytes*.
///
/// Bytes are handed back as `Data` rather than any UIKit/AppKit image type so
/// Core stays framework-free; the UI layer decodes them.
public protocol PhotoStore: Sendable {
    func photos(on wall: ID<Wall>) async throws -> [SitePhoto]
    func photo(_ id: ID<SitePhoto>) async throws -> SitePhoto
    func save(_ photo: SitePhoto) async throws
    func delete(_ id: ID<SitePhoto>) async throws

    /// Persist image bytes and return the reference to store on the `SitePhoto`.
    func storeImageData(_ data: Data, suggestedName: String) async throws -> ImageReference
    /// Resolve bytes for display/analysis. Throws `.imageDataUnavailable` if the
    /// user removed the underlying asset from their library.
    func imageData(for reference: ImageReference) async throws -> Data
}
