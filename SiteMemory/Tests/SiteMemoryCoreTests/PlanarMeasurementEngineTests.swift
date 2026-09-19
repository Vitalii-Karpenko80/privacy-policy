import XCTest
@testable import SiteMemoryCore

final class PlanarMeasurementEngineTests: XCTestCase {

    // A 4000x3000 photo whose full width spans a known 4.2 m wall.
    private let imageSize = ImageSize(pixelWidth: 4000, pixelHeight: 3000)
    private lazy var wallWidthReference = ReferenceScale(
        start: NormalizedPoint(x: 0, y: 0.5),
        end: NormalizedPoint(x: 1, y: 0.5),
        realLength: .metres(4.2)
    )

    func testMetresPerPixelMatchesReference() throws {
        let mpp = try PlanarMeasurementEngine.metresPerPixel(
            for: wallWidthReference, imageSize: imageSize
        )
        // 4.2 m across 4000 px.
        XCTAssertEqual(mpp, 4.2 / 4000, accuracy: 1e-9)
    }

    func testPositionFromLeftEdge() throws {
        // A cable tapped 1/8 of the way across the frame → ~525 mm from left.
        let point = NormalizedPoint(x: 0.125, y: 0.5)
        let position = try PlanarMeasurementEngine.position(
            of: point, reference: wallWidthReference, imageSize: imageSize
        )
        XCTAssertEqual(position.distanceFromLeft.millimetres, 525, accuracy: 0.5)
    }

    func testDegenerateReferenceThrows() {
        let degenerate = ReferenceScale(
            start: NormalizedPoint(x: 0.5, y: 0.5),
            end: NormalizedPoint(x: 0.5, y: 0.5),
            realLength: .metres(1)
        )
        XCTAssertThrowsError(
            try PlanarMeasurementEngine.metresPerPixel(for: degenerate, imageSize: imageSize)
        ) { error in
            XCTAssertEqual(error as? PlanarMeasurementEngine.MeasurementError, .degenerateReference)
        }
    }

    func testResolvingPositionsFillsAnnotations() {
        let annotation = HiddenObjectAnnotation(
            category: .waterPipe,
            region: .point(NormalizedPoint(x: 0.25, y: 0.4))
        )
        let photo = SitePhoto(
            wallID: .init(),
            imageReference: .appContainer(relativePath: "x.jpg"),
            imageSize: imageSize,
            referenceScale: wallWidthReference,
            annotations: [annotation]
        )
        let resolved = PlanarMeasurementEngine.resolvingPositions(in: photo)
        XCTAssertNotNil(resolved.annotations.first?.position)
        XCTAssertEqual(
            resolved.annotations.first?.position?.distanceFromLeft.millimetres ?? 0,
            1050, accuracy: 1
        )
    }

    func testResolvingPositionsWithoutReferenceIsNoOp() {
        let photo = SitePhoto(
            wallID: .init(),
            imageReference: .appContainer(relativePath: "x.jpg"),
            imageSize: imageSize,
            annotations: [HiddenObjectAnnotation(category: .metalStud, region: .point(.init(x: 0.5, y: 0.5)))]
        )
        let resolved = PlanarMeasurementEngine.resolvingPositions(in: photo)
        XCTAssertNil(resolved.annotations.first?.position)
    }

    func testConfidenceIsBoundedAndRewardsCoverage() {
        let short = ReferenceScale(
            start: NormalizedPoint(x: 0.49, y: 0.5),
            end: NormalizedPoint(x: 0.51, y: 0.5),
            realLength: .metres(0.1)
        )
        let shortConfidence = PlanarMeasurementEngine.confidence(for: short, imageSize: imageSize)
        let wideConfidence = PlanarMeasurementEngine.confidence(for: wallWidthReference, imageSize: imageSize)
        XCTAssertLessThan(shortConfidence, wideConfidence)
        XCTAssertGreaterThanOrEqual(shortConfidence, 0.55)
        XCTAssertLessThanOrEqual(wideConfidence, 0.85)
    }
}
