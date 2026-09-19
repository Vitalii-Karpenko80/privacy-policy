import Foundation
import SiteMemoryCore

#if canImport(PDFKit) && canImport(CoreGraphics) && canImport(ImageIO)
import PDFKit
import CoreGraphics
import ImageIO
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// Renders imported project PDFs into inspectable page rasters, entirely
/// on-device (PDFKit). This is what turns "upload the plan" into a page the
/// user can calibrate and pin photos onto.
///
/// It never reads bytes itself — the caller injects a provider (normally
/// `DocumentStore.documentData(for:)`) so this stays decoupled from storage and
/// the local-first guarantee is kept in one place.
public struct PDFKitDocumentRenderer: DocumentRendering {
    private let dataProvider: @Sendable (DocumentReference) async throws -> Data

    public init(dataProvider: @escaping @Sendable (DocumentReference) async throws -> Data) {
        self.dataProvider = dataProvider
    }

    public func pageCount(of reference: DocumentReference) async throws -> Int {
        let data = try await dataProvider(reference)
        guard let document = PDFDocument(data: data) else {
            throw StoreError.underlying("not a readable PDF")
        }
        return document.pageCount
    }

    public func renderPage(
        at index: Int,
        of reference: DocumentReference,
        maxPixelDimension: Double
    ) async throws -> RenderedPage {
        let data = try await dataProvider(reference)
        guard let document = PDFDocument(data: data), let page = document.page(at: index) else {
            throw StoreError.underlying("page \(index) unavailable")
        }

        let bounds = page.bounds(for: .mediaBox)
        let longest = max(bounds.width, bounds.height)
        let scale = longest > 0 ? min(maxPixelDimension / longest, 8) : 1
        let pixelWidth = Int((bounds.width * scale).rounded())
        let pixelHeight = Int((bounds.height * scale).rounded())

        guard
            let context = CGContext(
                data: nil,
                width: max(pixelWidth, 1),
                height: max(pixelHeight, 1),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw StoreError.underlying("could not allocate render context")
        }

        // Plans are drawn on white; flatten transparency so calibration taps
        // land on a clean raster.
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
        page.draw(with: .mediaBox, to: context)

        guard let cgImage = context.makeImage() else {
            throw StoreError.underlying("could not rasterize page")
        }

        return RenderedPage(
            imageData: try encodePNG(cgImage),
            size: ImageSize(pixelWidth: Double(pixelWidth), pixelHeight: Double(pixelHeight))
        )
    }

    private func encodePNG(_ image: CGImage) throws -> Data {
        let pngType: CFString
        #if canImport(UniformTypeIdentifiers)
        pngType = UTType.png.identifier as CFString
        #else
        pngType = "public.png" as CFString
        #endif
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output as CFMutableData, pngType, 1, nil) else {
            throw StoreError.underlying("could not create PNG encoder")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw StoreError.underlying("could not finalize PNG")
        }
        return output as Data
    }
}
#endif
