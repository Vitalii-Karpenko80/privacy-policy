import Foundation
import SiteMemoryCore

/// A RAM-only store for SwiftUI previews, tests and demos. Conforms to both
/// store protocols; an actor so concurrent access is safe by construction.
public actor InMemoryStore: ProjectStore, PhotoStore {
    private var projectsByID: [ID<Project>: Project] = [:]
    private var buildingsByID: [ID<Building>: Building] = [:]
    private var floorsByID: [ID<Floor>: Floor] = [:]
    private var roomsByID: [ID<Room>: Room] = [:]
    private var wallsByID: [ID<Wall>: Wall] = [:]
    private var photosByID: [ID<SitePhoto>: SitePhoto] = [:]
    private var imageBlobs: [String: Data] = [:]

    public init() {}

    // MARK: ProjectStore
    public func projects() -> [Project] { Array(projectsByID.values) }
    public func save(_ project: Project) { projectsByID[project.id] = project }
    public func delete(_ id: ID<Project>) { projectsByID[id] = nil }

    public func buildings(in project: ID<Project>) -> [Building] {
        buildingsByID.values.filter { $0.projectID == project }
    }
    public func floors(in building: ID<Building>) -> [Floor] {
        floorsByID.values.filter { $0.buildingID == building }
    }
    public func rooms(in floor: ID<Floor>) -> [Room] {
        roomsByID.values.filter { $0.floorID == floor }
    }
    public func walls(in room: ID<Room>) -> [Wall] {
        wallsByID.values.filter { $0.roomID == room }
    }

    public func save(_ building: Building) { buildingsByID[building.id] = building }
    public func save(_ floor: Floor) { floorsByID[floor.id] = floor }
    public func save(_ room: Room) { roomsByID[room.id] = room }
    public func save(_ wall: Wall) { wallsByID[wall.id] = wall }

    // MARK: PhotoStore
    public func photos(on wall: ID<Wall>) -> [SitePhoto] {
        photosByID.values.filter { $0.wallID == wall }.sorted { $0.capturedAt < $1.capturedAt }
    }
    public func photo(_ id: ID<SitePhoto>) throws -> SitePhoto {
        guard let photo = photosByID[id] else { throw StoreError.notFound }
        return photo
    }
    public func save(_ photo: SitePhoto) { photosByID[photo.id] = photo }
    public func delete(_ id: ID<SitePhoto>) { photosByID[id] = nil }

    public func storeImageData(_ data: Data, suggestedName: String) -> ImageReference {
        let key = "\(UUID().uuidString)-\(suggestedName)"
        imageBlobs[key] = data
        return .appContainer(relativePath: key)
    }
    public func imageData(for reference: ImageReference) throws -> Data {
        guard case let .appContainer(path) = reference, let data = imageBlobs[path] else {
            throw StoreError.imageDataUnavailable
        }
        return data
    }
}
