import Foundation
import SiteMemoryCore

#if canImport(Vision) && canImport(CoreGraphics)
import Vision
import CoreGraphics

/// On-device semantic search over site photos.
///
/// It runs Apple's Vision framework locally — no image ever leaves the phone,
/// which keeps the FieldReport privacy promise intact and is a hard requirement
/// for GDPR-sensitive EU jobsites. It widens recall beyond hand annotations:
/// even photos the user never tagged can be found by what the model sees.
///
/// The pipeline:
///   1. Fast path — delegate to `MetadataSearchIndex` for already-tagged data.
///   2. For photos lacking the queried category, classify the image with Vision
///      and map generic labels ("pipe", "cable", "wood") onto `ObjectCategory`.
///
/// The classifier here uses the built-in `VNClassifyImageRequest`. A bespoke
/// Core ML model trained on rough-in photos slots in behind the same protocol
/// without touching callers.
public struct VisionHiddenObjectSearching: HiddenObjectSearching {
    private let imageProvider: @Sendable (ImageReference) async throws -> CGImage
    private let fallback = MetadataSearchIndex()
    /// Minimum Vision confidence before a label is trusted.
    private let confidenceFloor: Float

    public init(
        confidenceFloor: Float = 0.25,
        imageProvider: @escaping @Sendable (ImageReference) async throws -> CGImage
    ) {
        self.confidenceFloor = confidenceFloor
        self.imageProvider = imageProvider
    }

    public func search(_ query: SiteQuery, in photos: [SitePhoto]) async throws -> [SearchResult] {
        let metadataResults = try await fallback.search(query, in: photos)
        guard !query.categories.isEmpty else { return metadataResults }

        let alreadyMatched = Set(metadataResults.map(\.photo.id))
        var augmented = metadataResults

        for photo in photos where !alreadyMatched.contains(photo.id) {
            guard let cgImage = try? await imageProvider(photo.imageReference) else { continue }
            let observed = try classify(cgImage)
            let matched = observed.intersection(query.categories)
            guard !matched.isEmpty else { continue }
            augmented.append(
                SearchResult(
                    photo: photo,
                    score: 0.4, // machine-inferred: below an explicit annotation
                    matchedCategories: matched
                )
            )
        }
        return augmented.sorted { $0.score > $1.score }
    }

    /// Map Vision's generic labels onto the SiteMemory taxonomy.
    private func classify(_ image: CGImage) throws -> Set<ObjectCategory> {
        let request = VNClassifyImageRequest()
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let labels = (request.results ?? [])
            .filter { $0.confidence >= confidenceFloor }
            .map { $0.identifier.lowercased() }

        var categories: Set<ObjectCategory> = []
        for label in labels {
            if let category = Self.labelMap.first(where: { label.contains($0.key) })?.value {
                categories.insert(category)
            }
        }
        return categories
    }

    /// Coarse keyword → category map. Deliberately conservative; the real gain
    /// comes from a fine-tuned model, but this makes the path exercisable today.
    private static let labelMap: [String: ObjectCategory] = [
        "pipe": .waterPipe,
        "plumbing": .waterPipe,
        "cable": .electricalCable,
        "wire": .electricalCable,
        "conduit": .electricalConduit,
        "duct": .ventilationDuct,
        "vent": .ventilationDuct,
        "stud": .metalStud,
        "beam": .woodFrame,
        "lumber": .woodFrame,
        "wood": .woodFrame,
        "insulation": .insulation
    ]
}
#endif
