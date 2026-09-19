import Foundation

/// A rendered raster of one document page, plus the pixel size it was rendered
/// at (which becomes the `PlanSheet.pageSize` used for calibration math).
public struct RenderedPage: Sendable {
    /// PNG bytes. `Data`, not a UI image type, so this stays framework-free.
    public let imageData: Data
    public let size: ImageSize

    public init(imageData: Data, size: ImageSize) {
        self.imageData = imageData
        self.size = size
    }
}

/// Turning a PDF into inspectable pages needs PDFKit, which is Apple-only — so
/// Core only declares the contract. `SiteMemoryDocuments` implements it; the
/// app and tests depend on this protocol, not on PDFKit being linked.
public protocol DocumentRendering: Sendable {
    func pageCount(of reference: DocumentReference) async throws -> Int

    /// Render a page, scaled so its longest side is at most `maxPixelDimension`.
    func renderPage(
        at index: Int,
        of reference: DocumentReference,
        maxPixelDimension: Double
    ) async throws -> RenderedPage
}
