import Foundation
import SiteMemoryCore

#if canImport(SwiftUI)
import SwiftUI

/// Drives the "project vs reality" overlay: loads planned + as-built markers for
/// a sheet, runs `PlanComparisonEngine`, and exposes a draw-ready overlay plus a
/// headline summary. Depends only on Core protocols.
@MainActor
public final class PlanComparisonViewModel: ObservableObject {
    @Published public private(set) var elements: [PlanOverlayElement] = []
    @Published public private(set) var summary: Summary?
    @Published public private(set) var pageImageData: Data?
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?

    public private(set) var sheet: PlanSheet
    private let document: ProjectDocument
    private let documentStore: DocumentStore
    private let photoStore: PhotoStore
    private let renderer: DocumentRendering
    public let unitSystem: UnitSystem
    private let options: ComparisonOptions
    private let renderMaxDimension: Double

    public init(
        document: ProjectDocument,
        sheet: PlanSheet,
        documentStore: DocumentStore,
        photoStore: PhotoStore,
        renderer: DocumentRendering,
        unitSystem: UnitSystem,
        options: ComparisonOptions = ComparisonOptions(),
        renderMaxDimension: Double = 2_000
    ) {
        self.document = document
        self.sheet = sheet
        self.documentStore = documentStore
        self.photoStore = photoStore
        self.renderer = renderer
        self.unitSystem = unitSystem
        self.options = options
        self.renderMaxDimension = renderMaxDimension
    }

    public struct Summary: Sendable {
        public let completionPercent: Int
        public let withinTolerance: Int
        public let outOfTolerance: Int
        public let missing: Int
        public let extra: Int
        public let worstDeviation: String?
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let page = renderer.renderPage(
                at: sheet.pageIndex, of: document.reference, maxPixelDimension: renderMaxDimension
            )
            let markers = try await documentStore.markers(on: sheet.id)
            let planned = markers.filter { $0.source == .planned }
            var asBuilt = markers.filter { $0.source == .asBuilt }

            // Fold in as-built markers derived from pinned photos, so reality
            // captured via the pinning flow is compared even if not re-entered.
            asBuilt += try await derivedAsBuiltMarkers()

            let comparison = try PlanComparisonEngine.compare(
                planned: planned, asBuilt: asBuilt, on: sheet, options: options
            )
            elements = comparison.overlayElements()
            summary = makeSummary(comparison)
            pageImageData = try await page.imageData
        } catch PlanComparisonEngine.ComparisonError.sheetNotCalibrated {
            errorMessage = "Calibrate the plan scale before comparing to reality."
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func derivedAsBuiltMarkers() async throws -> [PlanMarker] {
        let placements = try await documentStore.placements(on: sheet.id)
        var photos: [ID<SitePhoto>: SitePhoto] = [:]
        for placement in placements {
            if case let .photo(photoID) = placement.subject, photos[photoID] == nil {
                photos[photoID] = try? await photoStore.photo(photoID)
            }
        }
        return PlanComparisonEngine.asBuiltMarkers(fromPhotoPlacements: placements, photos: photos)
    }

    private func makeSummary(_ comparison: PlanComparison) -> Summary {
        Summary(
            completionPercent: Int((comparison.completion * 100).rounded()),
            withinTolerance: comparison.withinToleranceCount,
            outOfTolerance: comparison.outOfToleranceCount,
            missing: comparison.missing.count,
            extra: comparison.extra.count,
            worstDeviation: comparison.worstDeviation?.formatted(unitSystem)
        )
    }
}
#endif
