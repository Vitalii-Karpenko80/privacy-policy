import Foundation

/// One photograph taken of an open wall before it is closed up.
///
/// The image bytes themselves are *not* stored here — only a reference to where
/// they live locally. `PhotoStore` owns the bytes. This keeps the metadata
/// (which is what gets searched, exported and synced) light and Codable.
public struct SitePhoto: Codable, Hashable, Identifiable2, Sendable {
    public let id: ID<SitePhoto>
    public var wallID: ID<Wall>
    public var capturedAt: Date

    /// Where the image bytes live. Local-first: a file URL or a PHAsset
    /// local identifier, never a remote URL.
    public var imageReference: ImageReference
    public var imageSize: ImageSize

    /// User-placed scale. When present, positions can be computed for every
    /// annotation on this photo.
    public var referenceScale: ReferenceScale?

    public var annotations: [HiddenObjectAnnotation]

    /// On-device Vision tags (e.g. "pipe", "cable", "framing"). Free-text,
    /// used to widen search recall beyond the explicit annotations.
    public var visionTags: [String]

    /// Set once a spatial anchor has been captured for this photo (v2/LiDAR).
    public var spatialAnchorID: ID<SpatialAnchor>?

    public var note: String?

    public init(
        id: ID<SitePhoto> = .init(),
        wallID: ID<Wall>,
        capturedAt: Date = Date(),
        imageReference: ImageReference,
        imageSize: ImageSize,
        referenceScale: ReferenceScale? = nil,
        annotations: [HiddenObjectAnnotation] = [],
        visionTags: [String] = [],
        spatialAnchorID: ID<SpatialAnchor>? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.wallID = wallID
        self.capturedAt = capturedAt
        self.imageReference = imageReference
        self.imageSize = imageSize
        self.referenceScale = referenceScale
        self.annotations = annotations
        self.visionTags = visionTags
        self.spatialAnchorID = spatialAnchorID
        self.note = note
    }

    public var categories: Set<ObjectCategory> {
        Set(annotations.map(\.category))
    }
}

/// A local pointer to image bytes. Deliberately closed to remote URLs so the
/// "nothing leaves the device" guarantee is enforced by the type system.
public enum ImageReference: Codable, Hashable, Sendable {
    /// Apple Photos local identifier (`PHAsset.localIdentifier`).
    case photoLibrary(localIdentifier: String)
    /// A file inside the app's own container, stored relative to it.
    case appContainer(relativePath: String)
}
