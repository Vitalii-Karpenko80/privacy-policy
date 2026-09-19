import Foundation

// The spatial hierarchy of a jobsite:
//
//   Project → Building → Floor → Room → Wall → SitePhoto → HiddenObject
//
// Each level is a small value type. Relationships are expressed by parent id
// rather than by nesting objects, so a single entity can be loaded, edited and
// persisted without dragging its whole subtree into memory — the same shape a
// SwiftData / Core Data / SQLite store maps onto cleanly.

/// A jobsite. The top of the tree and the unit a contractor is billed for.
public struct Project: Codable, Hashable, Identifiable2, Sendable {
    public let id: ID<Project>
    public var name: String
    public var clientName: String?
    public var address: PostalAddress?
    /// Measurement system used when presenting distances for this project.
    /// Defaults follow the site's region (mm in the EU, inches in North America).
    public var unitSystem: UnitSystem
    public var createdAt: Date
    public var updatedAt: Date
    /// Opaque link back to a FieldReport project, when embedded. `nil` standalone.
    public var fieldReportProjectID: String?

    public init(
        id: ID<Project> = .init(),
        name: String,
        clientName: String? = nil,
        address: PostalAddress? = nil,
        unitSystem: UnitSystem = .metric,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        fieldReportProjectID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.clientName = clientName
        self.address = address
        self.unitSystem = unitSystem
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.fieldReportProjectID = fieldReportProjectID
    }
}

public struct Building: Codable, Hashable, Identifiable2, Sendable {
    public let id: ID<Building>
    public var projectID: ID<Project>
    public var name: String

    public init(id: ID<Building> = .init(), projectID: ID<Project>, name: String) {
        self.id = id
        self.projectID = projectID
        self.name = name
    }
}

public struct Floor: Codable, Hashable, Identifiable2, Sendable {
    public let id: ID<Floor>
    public var buildingID: ID<Building>
    public var name: String
    /// Storey number for sorting/search ("2nd floor"). Ground floor = 0.
    public var level: Int

    public init(id: ID<Floor> = .init(), buildingID: ID<Building>, name: String, level: Int) {
        self.id = id
        self.buildingID = buildingID
        self.name = name
        self.level = level
    }
}

public struct Room: Codable, Hashable, Identifiable2, Sendable {
    public let id: ID<Room>
    public var floorID: ID<Floor>
    public var name: String

    public init(id: ID<Room> = .init(), floorID: ID<Floor>, name: String) {
        self.id = id
        self.floorID = floorID
        self.name = name
    }
}

/// A single wall (or ceiling/floor plane) that will be closed up.
///
/// `orientation` lets the "point your phone at this wall" feature and the
/// search ("north wall of the kitchen") disambiguate between the surfaces of a
/// room without requiring full spatial data in the MVP.
public struct Wall: Codable, Hashable, Identifiable2, Sendable {
    public let id: ID<Wall>
    public var roomID: ID<Room>
    public var name: String
    public var orientation: SurfaceOrientation
    /// Known real width of the surface, if the user supplied it. Doubles as a
    /// convenient reference length for the planar measurement engine.
    public var knownWidth: Length?
    public var knownHeight: Length?

    public init(
        id: ID<Wall> = .init(),
        roomID: ID<Room>,
        name: String,
        orientation: SurfaceOrientation = .unspecified,
        knownWidth: Length? = nil,
        knownHeight: Length? = nil
    ) {
        self.id = id
        self.roomID = roomID
        self.name = name
        self.orientation = orientation
        self.knownWidth = knownWidth
        self.knownHeight = knownHeight
    }
}

public enum SurfaceOrientation: String, Codable, CaseIterable, Sendable {
    case north, east, south, west
    case ceiling, floor
    case unspecified
}

/// Minimal postal address. Kept flat and optional; SiteMemory never requires
/// it and never transmits it — it exists only to print on an exported report.
public struct PostalAddress: Codable, Hashable, Sendable {
    public var line1: String
    public var line2: String?
    public var city: String
    public var region: String?
    public var postalCode: String?
    /// ISO 3166-1 alpha-2 (e.g. "DE", "US", "CA"). Drives default units.
    public var countryCode: String?

    public init(
        line1: String,
        line2: String? = nil,
        city: String,
        region: String? = nil,
        postalCode: String? = nil,
        countryCode: String? = nil
    ) {
        self.line1 = line1
        self.line2 = line2
        self.city = city
        self.region = region
        self.postalCode = postalCode
        self.countryCode = countryCode
    }
}
