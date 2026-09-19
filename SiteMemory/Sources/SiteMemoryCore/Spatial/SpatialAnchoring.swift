import Foundation

/// A saved spatial reference tying a photo to a real place in the room, so a
/// later visit can re-localize and overlay the hidden objects on the live
/// camera. This is the v2 ("point your phone at the finished wall") capability.
///
/// Core only defines the *shape* of an anchor and the capture/relocalization
/// contract; the ARKit target implements it. Storing the world-map payload as
/// opaque `Data` keeps ARKit out of Core and out of the persisted schema's way.
public struct SpatialAnchor: Codable, Hashable, Identifiable2, Sendable {
    public let id: ID<SpatialAnchor>
    public var wallID: ID<Wall>
    public var capturedAt: Date
    /// Serialized `ARWorldMap` (or equivalent). Opaque to Core.
    public var worldMapData: Data
    /// 4x4 column-major transform of the anchor within that world map.
    public var transform: [Double]

    public init(
        id: ID<SpatialAnchor> = .init(),
        wallID: ID<Wall>,
        capturedAt: Date = Date(),
        worldMapData: Data,
        transform: [Double]
    ) {
        self.id = id
        self.wallID = wallID
        self.capturedAt = capturedAt
        self.worldMapData = worldMapData
        self.transform = transform
    }
}

/// Whether the current device can capture/relocalize spatial anchors.
public enum SpatialCapability: Sendable {
    case unavailable          // no ARKit / not supported
    case worldTracking        // ARKit without a depth sensor
    case lidar                // full LiDAR scene reconstruction
}

/// Implemented by `SiteMemoryARKit`. Kept as a protocol so the rest of the app
/// (and all tests) depend on the contract, not on ARKit being linked.
public protocol SpatialAnchoring: Sendable {
    var capability: SpatialCapability { get }

    /// Capture an anchor for a wall from the current AR session.
    func captureAnchor(for wall: ID<Wall>) async throws -> SpatialAnchor

    /// Attempt to relocalize against a stored anchor. Returns a stream of
    /// screen-space projections for the wall's hidden objects as tracking
    /// updates, so the UI can draw the "x-ray" overlay live.
    func relocalize(
        to anchor: SpatialAnchor,
        objects: [HiddenObjectAnnotation]
    ) -> AsyncThrowingStream<[ProjectedObject], Error>
}

/// A hidden object projected onto the current camera frame.
public struct ProjectedObject: Sendable {
    public let annotationID: ID<HiddenObjectAnnotation>
    public let category: ObjectCategory
    /// Normalized position within the current camera frame, or `nil` if the
    /// object is currently off-screen / occluded.
    public let screenPoint: NormalizedPoint?

    public init(
        annotationID: ID<HiddenObjectAnnotation>,
        category: ObjectCategory,
        screenPoint: NormalizedPoint?
    ) {
        self.annotationID = annotationID
        self.category = category
        self.screenPoint = screenPoint
    }
}
