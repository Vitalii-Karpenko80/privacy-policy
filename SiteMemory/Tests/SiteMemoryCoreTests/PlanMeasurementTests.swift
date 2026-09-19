import XCTest
@testable import SiteMemoryCore

final class PlanMeasurementTests: XCTestCase {

    // A 2000x1500 plan page whose full width represents 10 m.
    private let pageSize = ImageSize(pixelWidth: 2000, pixelHeight: 1500)

    private func sheet(calibrated: Bool) -> PlanSheet {
        PlanSheet(
            documentID: .init(),
            pageIndex: 0,
            name: "Level 2",
            pageSize: pageSize,
            calibration: calibrated
                ? ReferenceScale(
                    start: NormalizedPoint(x: 0, y: 0.5),
                    end: NormalizedPoint(x: 1, y: 0.5),
                    realLength: .metres(10)
                )
                : nil
        )
    }

    func testUncalibratedSheetReturnsNil() throws {
        let location = try PlanMeasurementEngine.location(
            of: NormalizedPoint(x: 0.3, y: 0.3), on: sheet(calibrated: false)
        )
        XCTAssertNil(location)
    }

    func testPinResolvesToRealLocation() throws {
        let placement = PlanPlacement(
            sheetID: .init(),
            subject: .photo(.init()),
            point: NormalizedPoint(x: 0.3, y: 0.4)
        )
        let location = try XCTUnwrap(
            try PlanMeasurementEngine.location(of: placement, on: sheet(calibrated: true))
        )
        // 0.3 * 2000 px * (10 m / 2000 px) = 3.0 m across.
        XCTAssertEqual(location.fromLeft.metres, 3.0, accuracy: 1e-6)
        // 0.4 * 1500 px * (10/2000) = 3.0 m down.
        XCTAssertEqual(location.fromTop.metres, 3.0, accuracy: 1e-6)
    }

    func testDistanceBetweenPinsOnPlan() throws {
        let distance = try XCTUnwrap(
            try PlanMeasurementEngine.distance(
                from: NormalizedPoint(x: 0.1, y: 0.5),
                to: NormalizedPoint(x: 0.6, y: 0.5),
                on: sheet(calibrated: true)
            )
        )
        // 0.5 of the width → 5 m.
        XCTAssertEqual(distance.metres, 5.0, accuracy: 1e-6)
    }

    func testSheetIsCalibratedFlag() {
        XCTAssertFalse(sheet(calibrated: false).isCalibrated)
        XCTAssertTrue(sheet(calibrated: true).isCalibrated)
    }
}
