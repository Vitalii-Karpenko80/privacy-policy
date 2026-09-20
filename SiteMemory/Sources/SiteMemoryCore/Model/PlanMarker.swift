import Foundation

/// Where a marker on a plan came from — the design intent, or what was actually
/// built. Comparing the two sets is the whole "project vs reality" feature.
public enum MarkerSource: String, Codable, Sendable {
    case planned    // from the drawings: where something is *supposed* to be
    case asBuilt    // from the site: where it actually ended up
}

/// A single categorized point on a calibrated plan sheet.
///
/// One type carries both the planned and the as-built worlds (distinguished by
/// `source`) so the comparison engine works on two homogeneous point sets and
/// the UI can draw them in one coordinate space.
public struct PlanMarker: Codable, Hashable, Identifiable2, Sendable {
    public let id: ID<PlanMarker>
    public var sheetID: ID<PlanSheet>
    public var source: MarkerSource
    public var category: ObjectCategory
    /// Location on the plan, in normalized page coordinates.
    public var point: NormalizedPoint
    public var label: String?
    /// Allowed deviation before an as-built match counts as out of tolerance.
    /// Planned markers only; `nil` falls back to the comparison default.
    public var tolerance: Length?
    /// Provenance for an as-built marker: the photo it was derived from.
    public var sourcePhotoID: ID<SitePhoto>?
    public var note: String?

    public init(
        id: ID<PlanMarker> = .init(),
        sheetID: ID<PlanSheet>,
        source: MarkerSource,
        category: ObjectCategory,
        point: NormalizedPoint,
        label: String? = nil,
        tolerance: Length? = nil,
        sourcePhotoID: ID<SitePhoto>? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.sheetID = sheetID
        self.source = source
        self.category = category
        self.point = point
        self.label = label
        self.tolerance = tolerance
        self.sourcePhotoID = sourcePhotoID
        self.note = note
    }
}
