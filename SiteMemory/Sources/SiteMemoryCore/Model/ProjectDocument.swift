import Foundation

// Project documents (PDF drawings) and the machinery that turns a plan page
// into a measurable coordinate space:
//
//   ProjectDocument (a PDF) → PlanSheet (one calibrated page) → PlanPlacement
//                                                               (a photo/wall
//                                                                pinned on it)
//
// A calibrated plan sheet is, geometrically, identical to a photo with a
// reference scale — so the same `PlanarMeasurementEngine` computes real
// positions on the floor plan. Nothing new to learn, one engine to trust.

/// A local pointer to document bytes. Closed to remote URLs on purpose: a PDF
/// the contractor imports is copied into the app container and never leaves it.
public enum DocumentReference: Codable, Hashable, Sendable {
    case appContainer(relativePath: String)
}

public enum DocumentKind: String, Codable, CaseIterable, Sendable {
    case floorPlan      // the plan we pin photos onto
    case blueprint      // general drawings / sections / elevations
    case specification
    case contract
    case other
}

/// An imported PDF attached to a project (plans, drawings, spec).
public struct ProjectDocument: Codable, Hashable, Identifiable2, Sendable {
    public let id: ID<ProjectDocument>
    public var projectID: ID<Project>
    public var title: String
    public var kind: DocumentKind
    public var reference: DocumentReference
    public var pageCount: Int
    public var importedAt: Date

    public init(
        id: ID<ProjectDocument> = .init(),
        projectID: ID<Project>,
        title: String,
        kind: DocumentKind = .floorPlan,
        reference: DocumentReference,
        pageCount: Int,
        importedAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.title = title
        self.kind = kind
        self.reference = reference
        self.pageCount = pageCount
        self.importedAt = importedAt
    }
}

/// One page of a `ProjectDocument`, promoted to a measurable floor plan.
///
/// `calibration` reuses `ReferenceScale`: two taps on the page whose real
/// separation is known (a dimension line, a door width, a scale bar). Once set,
/// every pin on the sheet resolves to metres. `pageSize` is the page's own
/// pixel/point size, needed only for aspect ratio.
public struct PlanSheet: Codable, Hashable, Identifiable2, Sendable {
    public let id: ID<PlanSheet>
    public var documentID: ID<ProjectDocument>
    public var pageIndex: Int
    /// The floor this plan represents, when known — links plan pins to the tree.
    public var floorID: ID<Floor>?
    public var name: String
    public var pageSize: ImageSize
    public var calibration: ReferenceScale?

    public init(
        id: ID<PlanSheet> = .init(),
        documentID: ID<ProjectDocument>,
        pageIndex: Int,
        floorID: ID<Floor>? = nil,
        name: String,
        pageSize: ImageSize,
        calibration: ReferenceScale? = nil
    ) {
        self.id = id
        self.documentID = documentID
        self.pageIndex = pageIndex
        self.floorID = floorID
        self.name = name
        self.pageSize = pageSize
        self.calibration = calibration
    }

    public var isCalibrated: Bool { calibration != nil }
}

/// What a pin on the plan refers to.
public enum PlanSubject: Codable, Hashable, Sendable {
    case photo(ID<SitePhoto>)
    case wall(ID<Wall>)
}

/// A pin binding a photo (or a wall) to a location on a plan sheet.
public struct PlanPlacement: Codable, Hashable, Identifiable2, Sendable {
    public let id: ID<PlanPlacement>
    public var sheetID: ID<PlanSheet>
    public var subject: PlanSubject
    /// Where on the page it sits, in normalized page coordinates.
    public var point: NormalizedPoint
    /// Direction the camera faced, degrees clockwise from plan-up. Optional.
    public var headingDegrees: Double?
    public var note: String?

    public init(
        id: ID<PlanPlacement> = .init(),
        sheetID: ID<PlanSheet>,
        subject: PlanSubject,
        point: NormalizedPoint,
        headingDegrees: Double? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.sheetID = sheetID
        self.subject = subject
        self.point = point
        self.headingDegrees = headingDegrees
        self.note = note
    }
}
