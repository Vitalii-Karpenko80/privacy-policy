import Foundation
import SiteMemoryCore

/// The default standalone store: metadata as JSON, images as files, all inside
/// the app's own container. Nothing is ever written outside `rootURL`, which is
/// how the "everything stays on the device" promise is kept concrete.
///
/// This is a straightforward reference implementation (one JSON document per
/// collection). When embedded in FieldReport, prefer conforming FieldReport's
/// existing database to the Core store protocols instead of running this.
public actor FileStore: ProjectStore, PhotoStore {
    private let rootURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(rootURL: URL, fileManager: FileManager = .default) throws {
        self.rootURL = rootURL
        self.fileManager = fileManager
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    private var metadataURL: URL { rootURL.appendingPathComponent("sitememory.json") }
    private var imagesDirectory: URL { rootURL.appendingPathComponent("images", isDirectory: true) }

    // A single serialized document. Fine for the data volumes a per-device
    // jobsite archive produces; swap for SQLite/SwiftData if it ever isn't.
    private struct Snapshot: Codable {
        var projects: [Project] = []
        var buildings: [Building] = []
        var floors: [Floor] = []
        var rooms: [Room] = []
        var walls: [Wall] = []
        var photos: [SitePhoto] = []
    }

    private var cached: Snapshot?

    private func load() throws -> Snapshot {
        if let cached { return cached }
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            let empty = Snapshot()
            cached = empty
            return empty
        }
        let data = try Data(contentsOf: metadataURL)
        let snapshot = try decoder.decode(Snapshot.self, from: data)
        cached = snapshot
        return snapshot
    }

    private func persist(_ snapshot: Snapshot) throws {
        cached = snapshot
        let data = try encoder.encode(snapshot)
        try data.write(to: metadataURL, options: .atomic)
    }

    // MARK: ProjectStore
    public func projects() throws -> [Project] { try load().projects }

    public func save(_ project: Project) throws {
        var s = try load()
        s.projects.removeAll { $0.id == project.id }
        s.projects.append(project)
        try persist(s)
    }
    public func delete(_ id: ID<Project>) throws {
        var s = try load(); s.projects.removeAll { $0.id == id }; try persist(s)
    }

    public func buildings(in project: ID<Project>) throws -> [Building] {
        try load().buildings.filter { $0.projectID == project }
    }
    public func floors(in building: ID<Building>) throws -> [Floor] {
        try load().floors.filter { $0.buildingID == building }
    }
    public func rooms(in floor: ID<Floor>) throws -> [Room] {
        try load().rooms.filter { $0.floorID == floor }
    }
    public func walls(in room: ID<Room>) throws -> [Wall] {
        try load().walls.filter { $0.roomID == room }
    }

    public func save(_ building: Building) throws {
        var s = try load(); s.buildings.removeAll { $0.id == building.id }
        s.buildings.append(building); try persist(s)
    }
    public func save(_ floor: Floor) throws {
        var s = try load(); s.floors.removeAll { $0.id == floor.id }
        s.floors.append(floor); try persist(s)
    }
    public func save(_ room: Room) throws {
        var s = try load(); s.rooms.removeAll { $0.id == room.id }
        s.rooms.append(room); try persist(s)
    }
    public func save(_ wall: Wall) throws {
        var s = try load(); s.walls.removeAll { $0.id == wall.id }
        s.walls.append(wall); try persist(s)
    }

    // MARK: PhotoStore
    public func photos(on wall: ID<Wall>) throws -> [SitePhoto] {
        try load().photos.filter { $0.wallID == wall }.sorted { $0.capturedAt < $1.capturedAt }
    }
    public func photo(_ id: ID<SitePhoto>) throws -> SitePhoto {
        guard let photo = try load().photos.first(where: { $0.id == id }) else {
            throw StoreError.notFound
        }
        return photo
    }
    public func save(_ photo: SitePhoto) throws {
        var s = try load(); s.photos.removeAll { $0.id == photo.id }
        s.photos.append(photo); try persist(s)
    }
    public func delete(_ id: ID<SitePhoto>) throws {
        var s = try load(); s.photos.removeAll { $0.id == id }; try persist(s)
    }

    public func storeImageData(_ data: Data, suggestedName: String) throws -> ImageReference {
        let name = "\(UUID().uuidString)-\(suggestedName)"
        let url = imagesDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return .appContainer(relativePath: "images/\(name)")
    }
    public func imageData(for reference: ImageReference) throws -> Data {
        guard case let .appContainer(path) = reference else {
            // PHAsset-backed images are resolved by the UI layer via PhotoKit,
            // not by the file store.
            throw StoreError.imageDataUnavailable
        }
        let url = rootURL.appendingPathComponent(path)
        guard fileManager.fileExists(atPath: url.path) else {
            throw StoreError.imageDataUnavailable
        }
        return try Data(contentsOf: url)
    }
}
