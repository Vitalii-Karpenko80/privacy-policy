import Foundation

/// The verdict for one item when project meets reality.
public enum ComparisonStatus: String, Codable, Sendable {
    case match           // built where planned, within tolerance
    case outOfTolerance  // built, but moved further than allowed
    case missing         // planned, but nothing built/found near it
    case extra           // built, but not on the plan
}

/// A planned marker paired with its as-built counterpart.
public struct MatchResult: Hashable, Sendable {
    public let planned: PlanMarker
    public let asBuilt: PlanMarker
    /// Real-world distance between planned and as-built positions.
    public let deviation: Length
    public let isWithinTolerance: Bool

    public var status: ComparisonStatus { isWithinTolerance ? .match : .outOfTolerance }

    public init(planned: PlanMarker, asBuilt: PlanMarker, deviation: Length, isWithinTolerance: Bool) {
        self.planned = planned
        self.asBuilt = asBuilt
        self.deviation = deviation
        self.isWithinTolerance = isWithinTolerance
    }
}

/// Knobs for the matching pass.
public struct ComparisonOptions: Sendable {
    /// A planned and an as-built marker can only be paired within this range.
    public var maxMatchDistance: Length
    /// Tolerance used when a planned marker specifies none of its own.
    public var defaultTolerance: Length
    /// Require planned and as-built to share a category to be paired.
    public var requireSameCategory: Bool

    public init(
        maxMatchDistance: Length = .metres(0.5),
        defaultTolerance: Length = .millimetres(50),
        requireSameCategory: Bool = true
    ) {
        self.maxMatchDistance = maxMatchDistance
        self.defaultTolerance = defaultTolerance
        self.requireSameCategory = requireSameCategory
    }
}

/// The full result of overlaying reality onto the project.
public struct PlanComparison: Sendable {
    public let matches: [MatchResult]
    public let missing: [PlanMarker]   // planned, not built/found
    public let extra: [PlanMarker]     // built, not on the plan

    public init(matches: [MatchResult], missing: [PlanMarker], extra: [PlanMarker]) {
        self.matches = matches
        self.missing = missing
        self.extra = extra
    }

    public var withinToleranceCount: Int { matches.filter(\.isWithinTolerance).count }
    public var outOfToleranceCount: Int { matches.count - withinToleranceCount }

    /// The largest deviation among matched items, if any — the headline number
    /// for "how far did reality drift from the drawings".
    public var worstDeviation: Length? { matches.map(\.deviation).max() }

    /// How complete the build is against the plan: matched / planned total.
    public var completion: Double {
        let plannedTotal = matches.count + missing.count
        guard plannedTotal > 0 else { return extra.isEmpty ? 1 : 0 }
        return Double(matches.count) / Double(plannedTotal)
    }

    /// Flattened, draw-ready overlay for the UI. Planned/as-built points and a
    /// status drive colour and connector lines on the plan.
    public func overlayElements() -> [PlanOverlayElement] {
        var elements: [PlanOverlayElement] = []
        for match in matches {
            elements.append(
                PlanOverlayElement(
                    id: match.planned.id,
                    status: match.status,
                    category: match.planned.category,
                    plannedPoint: match.planned.point,
                    asBuiltPoint: match.asBuilt.point,
                    deviation: match.deviation
                )
            )
        }
        for marker in missing {
            elements.append(
                PlanOverlayElement(
                    id: marker.id, status: .missing, category: marker.category,
                    plannedPoint: marker.point, asBuiltPoint: nil, deviation: nil
                )
            )
        }
        for marker in extra {
            elements.append(
                PlanOverlayElement(
                    id: marker.id, status: .extra, category: marker.category,
                    plannedPoint: nil, asBuiltPoint: marker.point, deviation: nil
                )
            )
        }
        return elements
    }
}

/// One drawable item of the comparison overlay.
public struct PlanOverlayElement: Identifiable, Sendable {
    public let id: ID<PlanMarker>
    public let status: ComparisonStatus
    public let category: ObjectCategory
    public let plannedPoint: NormalizedPoint?
    public let asBuiltPoint: NormalizedPoint?
    public let deviation: Length?

    public init(
        id: ID<PlanMarker>,
        status: ComparisonStatus,
        category: ObjectCategory,
        plannedPoint: NormalizedPoint?,
        asBuiltPoint: NormalizedPoint?,
        deviation: Length?
    ) {
        self.id = id
        self.status = status
        self.category = category
        self.plannedPoint = plannedPoint
        self.asBuiltPoint = asBuiltPoint
        self.deviation = deviation
    }
}
