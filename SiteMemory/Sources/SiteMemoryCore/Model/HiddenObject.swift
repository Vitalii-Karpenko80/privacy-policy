import Foundation

/// What kind of thing is hidden behind the finished surface.
///
/// The taxonomy is the backbone of search ("show me every wall with a water
/// pipe behind it") and of the Vision model's label set. Keep raw values
/// stable — they are persisted and, later, become ML class names.
public enum ObjectCategory: String, Codable, CaseIterable, Sendable {
    case electricalCable
    case electricalConduit
    case junctionBox
    case socketBackBox
    case waterPipe
    case drainPipe
    case gasPipe
    case underfloorHeating
    case ventilationDuct
    case metalStud
    case woodFrame
    case embed          // закладная: backing/blocking for a future fixture
    case insulation
    case vaporBarrier
    case other

    /// Non-localized key; the UI layer maps this to a localized display string
    /// and an SF Symbol. Kept out of Core so Core stays framework-free.
    public var localizationKey: String { "object.category.\(rawValue)" }
}

/// A region on a photo where an object was recorded. In the MVP this is a
/// single tap; later versions may store a rectangle or polygon.
public enum HiddenObjectRegion: Codable, Hashable, Sendable {
    case point(NormalizedPoint)
    case segment(start: NormalizedPoint, end: NormalizedPoint)
    case rect(origin: NormalizedPoint, width: Double, height: Double)

    /// A representative point, used when computing a single planar position.
    public var anchorPoint: NormalizedPoint {
        switch self {
        case let .point(p): return p
        case let .segment(start, end):
            return NormalizedPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        case let .rect(origin, w, h):
            return NormalizedPoint(x: origin.x + w / 2, y: origin.y + h / 2)
        }
    }
}

/// A single recorded object on a photo: what it is, where on the image it was
/// marked, and — once a reference scale exists — where it sits on the wall.
public struct HiddenObjectAnnotation: Codable, Hashable, Identifiable2, Sendable {
    public let id: ID<HiddenObjectAnnotation>
    public var category: ObjectCategory
    public var region: HiddenObjectRegion
    /// Computed lazily by `PlanarMeasurementEngine`; `nil` until a reference
    /// scale is set on the parent photo.
    public var position: PlanarPosition?
    public var note: String?
    /// True when the label came from the Vision model rather than a human tap.
    public var isMachineSuggested: Bool

    public init(
        id: ID<HiddenObjectAnnotation> = .init(),
        category: ObjectCategory,
        region: HiddenObjectRegion,
        position: PlanarPosition? = nil,
        note: String? = nil,
        isMachineSuggested: Bool = false
    ) {
        self.id = id
        self.category = category
        self.region = region
        self.position = position
        self.note = note
        self.isMachineSuggested = isMachineSuggested
    }
}
