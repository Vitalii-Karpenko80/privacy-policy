import Foundation

/// The search capability, as a protocol so callers never care whether results
/// came from cheap metadata matching or from an on-device Vision pass.
public protocol HiddenObjectSearching: Sendable {
    func search(_ query: SiteQuery, in photos: [SitePhoto]) async throws -> [SearchResult]
}

/// The always-available, offline, zero-dependency implementation.
///
/// It matches only on data already captured — explicit annotations, Vision
/// tags saved earlier, notes and dates. `SiteMemoryVision` layers semantic
/// image analysis on top of this for photos that were never hand-annotated.
public struct MetadataSearchIndex: HiddenObjectSearching {
    public init() {}

    public func search(_ query: SiteQuery, in photos: [SitePhoto]) async throws -> [SearchResult] {
        guard !query.isEmpty else {
            return photos.map { SearchResult(photo: $0, score: 0, matchedCategories: []) }
        }

        let needle = query.text?.lowercased()

        return photos.compactMap { photo -> SearchResult? in
            if let range = query.dateRange, !range.contains(photo.capturedAt) {
                return nil
            }

            let photoCategories = photo.categories
            let matchedCategories: Set<ObjectCategory>
            if query.categories.isEmpty {
                matchedCategories = []
            } else {
                matchedCategories = photoCategories.intersection(query.categories)
                if matchedCategories.isEmpty { return nil }
            }

            var textMatched = true
            if let needle, !needle.isEmpty {
                let haystack = ([photo.note] + photo.visionTags)
                    .compactMap { $0?.lowercased() }
                    .joined(separator: " ")
                textMatched = haystack.contains(needle)
                    || photo.visionTags.contains { $0.lowercased().contains(needle) }
                if !textMatched && query.categories.isEmpty { return nil }
            }

            // Score: category hits dominate; text and tags nudge.
            var score = Double(matchedCategories.count) * 0.5
            if needle != nil, textMatched { score += 0.3 }
            score += min(Double(photo.visionTags.count) * 0.02, 0.2)

            return SearchResult(
                photo: photo,
                score: min(score, 1),
                matchedCategories: matchedCategories
            )
        }
        .sorted { $0.score > $1.score }
    }
}
