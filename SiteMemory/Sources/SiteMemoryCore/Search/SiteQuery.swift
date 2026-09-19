import Foundation

/// A structured search over a site's photo memory.
///
/// Natural-language questions like *"where did we leave TV backing on the 2nd
/// floor?"* or *"show every wall with a water pipe behind it"* are parsed into
/// this structure (by a rules-based parser now, an LLM later) and then run by a
/// `HiddenObjectSearching` implementation. Keeping the query structured means
/// the same intent runs identically offline (metadata) or with Vision.
public struct SiteQuery: Hashable, Sendable {
    public var categories: Set<ObjectCategory>
    public var floorLevels: Set<Int>
    public var orientations: Set<SurfaceOrientation>
    public var dateRange: ClosedRange<Date>?
    /// Free text matched against notes, room/wall names and Vision tags.
    public var text: String?

    public init(
        categories: Set<ObjectCategory> = [],
        floorLevels: Set<Int> = [],
        orientations: Set<SurfaceOrientation> = [],
        dateRange: ClosedRange<Date>? = nil,
        text: String? = nil
    ) {
        self.categories = categories
        self.floorLevels = floorLevels
        self.orientations = orientations
        self.dateRange = dateRange
        self.text = text
    }

    public var isEmpty: Bool {
        categories.isEmpty && floorLevels.isEmpty && orientations.isEmpty
            && dateRange == nil && (text?.isEmpty ?? true)
    }
}

/// A photo that matched, plus why — so the UI can explain the result and rank.
public struct SearchResult: Hashable, Sendable {
    public let photo: SitePhoto
    /// 0…1 relevance. Exact category matches score high; fuzzy Vision-tag
    /// matches score lower.
    public let score: Double
    public let matchedCategories: Set<ObjectCategory>

    public init(photo: SitePhoto, score: Double, matchedCategories: Set<ObjectCategory>) {
        self.photo = photo
        self.score = score
        self.matchedCategories = matchedCategories
    }
}
