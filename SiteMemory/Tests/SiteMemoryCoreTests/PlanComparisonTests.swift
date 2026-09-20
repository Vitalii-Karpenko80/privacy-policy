import XCTest
@testable import SiteMemoryCore

final class PlanComparisonTests: XCTestCase {

    // A 2000x1500 plan whose full width is 10 m → 200 px per metre.
    private let pageSize = ImageSize(pixelWidth: 2000, pixelHeight: 1500)

    private func calibratedSheet() -> PlanSheet {
        PlanSheet(
            documentID: .init(),
            pageIndex: 0,
            name: "Level 1",
            pageSize: pageSize,
            calibration: ReferenceScale(
                start: NormalizedPoint(x: 0, y: 0.5),
                end: NormalizedPoint(x: 1, y: 0.5),
                realLength: .metres(10)
            )
        )
    }

    private func marker(
        _ source: MarkerSource,
        _ category: ObjectCategory,
        x: Double,
        y: Double,
        tolerance: Length? = nil
    ) -> PlanMarker {
        PlanMarker(
            sheetID: .init(), source: source, category: category,
            point: NormalizedPoint(x: x, y: y), tolerance: tolerance
        )
    }

    func testUncalibratedSheetThrows() {
        var sheet = calibratedSheet()
        sheet.calibration = nil
        XCTAssertThrowsError(
            try PlanComparisonEngine.compare(planned: [], asBuilt: [], on: sheet)
        ) { XCTAssertEqual($0 as? PlanComparisonEngine.ComparisonError, .sheetNotCalibrated) }
    }

    func testMatchWithinTolerance() throws {
        // Planned socket at 2.0 m, as-built 4 cm away (0.002 in x = 0.4 m? no).
        // 0.01 of width = 0.1 m. Use 0.002 → 0.04 m = 40 mm, under 50 mm default.
        let planned = marker(.planned, .socketBackBox, x: 0.20, y: 0.5)
        let asBuilt = marker(.asBuilt, .socketBackBox, x: 0.204, y: 0.5)
        let result = try PlanComparisonEngine.compare(
            planned: [planned], asBuilt: [asBuilt], on: calibratedSheet()
        )
        XCTAssertEqual(result.matches.count, 1)
        XCTAssertTrue(result.matches.first?.isWithinTolerance ?? false)
        XCTAssertEqual(result.matches.first?.deviation.millimetres ?? 0, 40, accuracy: 1)
        XCTAssertTrue(result.missing.isEmpty)
        XCTAssertTrue(result.extra.isEmpty)
    }

    func testMatchOutOfTolerance() throws {
        // 0.02 of width = 0.2 m = 200 mm, over the 50 mm default tolerance.
        let planned = marker(.planned, .waterPipe, x: 0.20, y: 0.5)
        let asBuilt = marker(.asBuilt, .waterPipe, x: 0.22, y: 0.5)
        let result = try PlanComparisonEngine.compare(
            planned: [planned], asBuilt: [asBuilt], on: calibratedSheet()
        )
        XCTAssertEqual(result.matches.count, 1)
        XCTAssertFalse(result.matches.first?.isWithinTolerance ?? true)
        XCTAssertEqual(result.matches.first?.status, .outOfTolerance)
    }

    func testMissingAndExtra() throws {
        let planned = marker(.planned, .junctionBox, x: 0.10, y: 0.5)
        // As-built is far away and a different category → no match.
        let asBuilt = marker(.asBuilt, .ventilationDuct, x: 0.90, y: 0.5)
        let result = try PlanComparisonEngine.compare(
            planned: [planned], asBuilt: [asBuilt], on: calibratedSheet()
        )
        XCTAssertTrue(result.matches.isEmpty)
        XCTAssertEqual(result.missing.map(\.category), [.junctionBox])
        XCTAssertEqual(result.extra.map(\.category), [.ventilationDuct])
        XCTAssertEqual(result.completion, 0, accuracy: 1e-9)
    }

    func testCategoryMustMatchWhenRequired() throws {
        let planned = marker(.planned, .socketBackBox, x: 0.20, y: 0.5)
        let asBuilt = marker(.asBuilt, .junctionBox, x: 0.201, y: 0.5) // adjacent, wrong type
        let result = try PlanComparisonEngine.compare(
            planned: [planned], asBuilt: [asBuilt], on: calibratedSheet()
        )
        XCTAssertTrue(result.matches.isEmpty)
        XCTAssertEqual(result.missing.count, 1)
        XCTAssertEqual(result.extra.count, 1)
    }

    func testGreedyMatchingPrefersNearest() throws {
        let planned = marker(.planned, .metalStud, x: 0.50, y: 0.5)
        let near = marker(.asBuilt, .metalStud, x: 0.505, y: 0.5) // 0.05 m away
        let far = marker(.asBuilt, .metalStud, x: 0.54, y: 0.5)   // 0.40 m away (in range, loses)
        let result = try PlanComparisonEngine.compare(
            planned: [planned], asBuilt: [near, far], on: calibratedSheet()
        )
        XCTAssertEqual(result.matches.count, 1)
        XCTAssertEqual(result.matches.first?.asBuilt.id, near.id)
        XCTAssertEqual(result.extra.map(\.id), [far.id])
    }

    func testCompletionAndOverlayElements() throws {
        let planned = [
            marker(.planned, .socketBackBox, x: 0.20, y: 0.3),
            marker(.planned, .socketBackBox, x: 0.60, y: 0.3)
        ]
        let asBuilt = [marker(.asBuilt, .socketBackBox, x: 0.202, y: 0.3)]
        let result = try PlanComparisonEngine.compare(
            planned: planned, asBuilt: asBuilt, on: calibratedSheet()
        )
        XCTAssertEqual(result.completion, 0.5, accuracy: 1e-9)
        // One matched (both points), one missing (planned point only).
        let elements = result.overlayElements()
        XCTAssertEqual(elements.count, 2)
        XCTAssertEqual(elements.filter { $0.status == .missing }.count, 1)
        XCTAssertNotNil(elements.first { $0.status == .match }?.asBuiltPoint)
    }

    func testAsBuiltMarkersDerivedFromPinnedPhotos() {
        let sheetID = ID<PlanSheet>()
        let photoID = ID<SitePhoto>()
        let photo = SitePhoto(
            id: photoID,
            wallID: .init(),
            imageReference: .appContainer(relativePath: "p.jpg"),
            imageSize: pageSize,
            annotations: [
                HiddenObjectAnnotation(category: .waterPipe, region: .point(.init(x: 0.5, y: 0.5))),
                HiddenObjectAnnotation(category: .electricalCable, region: .point(.init(x: 0.6, y: 0.5)))
            ]
        )
        let placement = PlanPlacement(
            sheetID: sheetID, subject: .photo(photoID), point: NormalizedPoint(x: 0.3, y: 0.4)
        )
        let markers = PlanComparisonEngine.asBuiltMarkers(
            fromPhotoPlacements: [placement], photos: [photoID: photo]
        )
        XCTAssertEqual(markers.count, 2)
        XCTAssertTrue(markers.allSatisfy { $0.source == .asBuilt })
        XCTAssertTrue(markers.allSatisfy { $0.point == NormalizedPoint(x: 0.3, y: 0.4) })
        XCTAssertEqual(Set(markers.map(\.category)), [.waterPipe, .electricalCable])
    }
}
