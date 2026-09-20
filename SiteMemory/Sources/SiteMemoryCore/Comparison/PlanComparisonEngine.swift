import Foundation

/// Overlays the as-built reality onto the planned project and reports the
/// discrepancies: what matched (and by how much it drifted), what is missing,
/// and what was built off-plan.
///
/// Matching is greedy nearest-first: all candidate planned↔as-built pairs of
/// the same category within `maxMatchDistance` are ranked by real distance and
/// assigned closest-first, each marker used once. Simple, stable, and good
/// enough for the point densities a jobsite plan carries; a global optimal
/// assignment (Hungarian) can replace it behind this same API if ever needed.
public enum PlanComparisonEngine {

    public enum ComparisonError: Error, Equatable {
        /// Deviations are meaningless without a plan scale.
        case sheetNotCalibrated
    }

    public static func compare(
        planned: [PlanMarker],
        asBuilt: [PlanMarker],
        on sheet: PlanSheet,
        options: ComparisonOptions = ComparisonOptions()
    ) throws -> PlanComparison {
        guard sheet.isCalibrated else { throw ComparisonError.sheetNotCalibrated }

        struct Candidate { let planned: Int; let asBuilt: Int; let metres: Double }

        var candidates: [Candidate] = []
        for (pi, p) in planned.enumerated() {
            for (ai, a) in asBuilt.enumerated() {
                if options.requireSameCategory && p.category != a.category { continue }
                guard let distance = try PlanMeasurementEngine.distance(
                    from: p.point, to: a.point, on: sheet
                ) else { continue }
                if distance.metres <= options.maxMatchDistance.metres {
                    candidates.append(Candidate(planned: pi, asBuilt: ai, metres: distance.metres))
                }
            }
        }
        candidates.sort { $0.metres < $1.metres }

        var usedPlanned = Set<Int>()
        var usedAsBuilt = Set<Int>()
        var matches: [MatchResult] = []
        for candidate in candidates {
            guard !usedPlanned.contains(candidate.planned),
                  !usedAsBuilt.contains(candidate.asBuilt) else { continue }
            usedPlanned.insert(candidate.planned)
            usedAsBuilt.insert(candidate.asBuilt)
            let plannedMarker = planned[candidate.planned]
            let asBuiltMarker = asBuilt[candidate.asBuilt]
            let tolerance = plannedMarker.tolerance ?? options.defaultTolerance
            matches.append(
                MatchResult(
                    planned: plannedMarker,
                    asBuilt: asBuiltMarker,
                    deviation: .metres(candidate.metres),
                    isWithinTolerance: candidate.metres <= tolerance.metres
                )
            )
        }

        let missing = planned.enumerated()
            .filter { !usedPlanned.contains($0.offset) }.map(\.element)
        let extra = asBuilt.enumerated()
            .filter { !usedAsBuilt.contains($0.offset) }.map(\.element)

        return PlanComparison(matches: matches, missing: missing, extra: extra)
    }

    /// Derive as-built markers from the photos already pinned on the plan, so
    /// comparison reuses the data captured by the pinning feature: each pinned
    /// photo contributes one marker per hidden-object category it records.
    public static func asBuiltMarkers(
        fromPhotoPlacements placements: [PlanPlacement],
        photos: [ID<SitePhoto>: SitePhoto]
    ) -> [PlanMarker] {
        placements.flatMap { placement -> [PlanMarker] in
            guard case let .photo(photoID) = placement.subject,
                  let photo = photos[photoID] else { return [] }
            return photo.categories.map { category in
                PlanMarker(
                    sheetID: placement.sheetID,
                    source: .asBuilt,
                    category: category,
                    point: placement.point,
                    sourcePhotoID: photoID
                )
            }
        }
    }
}
