import Foundation
import SiteMemoryCore

#if canImport(SwiftUI)
import SwiftUI

/// Drives the floor-plan board: renders an imported PDF page, overlays the
/// pinned photos/walls, and turns each pin into a real-world location using the
/// sheet's calibration. Depends only on Core protocols, so the PDFKit renderer
/// and whichever store are injected by the host.
@MainActor
public final class PlanBoardViewModel: ObservableObject {
    @Published public private(set) var pageImageData: Data?
    @Published public private(set) var pins: [Pin] = []
    @Published public private(set) var isCalibrated: Bool
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?

    public private(set) var sheet: PlanSheet
    private let document: ProjectDocument
    private let documentStore: DocumentStore
    private let renderer: DocumentRendering
    private let unitSystem: UnitSystem
    private let renderMaxDimension: Double

    public init(
        document: ProjectDocument,
        sheet: PlanSheet,
        documentStore: DocumentStore,
        renderer: DocumentRendering,
        unitSystem: UnitSystem,
        renderMaxDimension: Double = 2_000
    ) {
        self.document = document
        self.sheet = sheet
        self.documentStore = documentStore
        self.renderer = renderer
        self.unitSystem = unitSystem
        self.renderMaxDimension = renderMaxDimension
        self.isCalibrated = sheet.isCalibrated
    }

    public struct Pin: Identifiable {
        public let id: ID<PlanPlacement>
        public let point: NormalizedPoint
        public let title: String
        public let detail: String
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await renderer.renderPage(
                at: sheet.pageIndex, of: document.reference, maxPixelDimension: renderMaxDimension
            )
            pageImageData = page.imageData
            await refreshPins()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Set the plan scale from two taps a known real distance apart, then
    /// re-resolve every pin against it.
    public func calibrate(from start: NormalizedPoint, to end: NormalizedPoint, realLength: Length) async {
        sheet.calibration = ReferenceScale(start: start, end: end, realLength: realLength)
        isCalibrated = true
        do {
            try await documentStore.save(sheet)
            await refreshPins()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Pin a photo or wall at a normalized point on the plan.
    public func addPin(_ subject: PlanSubject, at point: NormalizedPoint, note: String? = nil) async {
        let placement = PlanPlacement(sheetID: sheet.id, subject: subject, point: point, note: note)
        do {
            try await documentStore.save(placement)
            await refreshPins()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func refreshPins() async {
        do {
            let placements = try await documentStore.placements(on: sheet.id)
            pins = placements.map { placement in
                Pin(
                    id: placement.id,
                    point: placement.point,
                    title: title(for: placement.subject),
                    detail: detail(for: placement)
                )
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func detail(for placement: PlanPlacement) -> String {
        guard let location = try? PlanMeasurementEngine.location(of: placement, on: sheet),
              let location else {
            return "tap two points to set the plan scale"
        }
        let x = location.fromLeft.formatted(unitSystem)
        let y = location.fromTop.formatted(unitSystem)
        return "\(x) × \(y) on plan"
    }

    private func title(for subject: PlanSubject) -> String {
        switch subject {
        case .photo: return "Photo"
        case .wall: return "Wall"
        }
    }
}
#endif
