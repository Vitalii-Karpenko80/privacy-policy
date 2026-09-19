import Foundation

/// A real-world location on a floor plan, as offsets from the sheet's edges.
/// Distinct from `PlanarPosition` (which is a position on a *wall* plane) only
/// to keep report text unambiguous — *"3.20 m × 1.50 m on the Level 2 plan"*.
public struct PlanLocation: Codable, Hashable, Sendable {
    public var fromLeft: Length
    public var fromTop: Length
    public var confidence: Double

    public init(fromLeft: Length, fromTop: Length, confidence: Double) {
        self.fromLeft = fromLeft
        self.fromTop = fromTop
        self.confidence = confidence
    }
}

/// Resolves plan pins to metres. A calibrated plan sheet is geometrically the
/// same problem as a photo with a reference scale, so this delegates straight
/// to `PlanarMeasurementEngine` rather than reimplementing the math.
public enum PlanMeasurementEngine {

    public static func location(
        of point: NormalizedPoint,
        on sheet: PlanSheet
    ) throws -> PlanLocation? {
        guard let calibration = sheet.calibration else { return nil }
        let position = try PlanarMeasurementEngine.position(
            of: point,
            reference: calibration,
            imageSize: sheet.pageSize
        )
        return PlanLocation(
            fromLeft: position.distanceFromLeft,
            fromTop: position.distanceFromTop,
            confidence: position.confidence
        )
    }

    public static func location(
        of placement: PlanPlacement,
        on sheet: PlanSheet
    ) throws -> PlanLocation? {
        try location(of: placement.point, on: sheet)
    }

    /// Straight-line real distance between two pins on the same calibrated sheet
    /// — e.g. how far the socket pin is from the door pin on the plan.
    public static func distance(
        from a: NormalizedPoint,
        to b: NormalizedPoint,
        on sheet: PlanSheet
    ) throws -> Length? {
        guard let calibration = sheet.calibration else { return nil }
        let mpp = try PlanarMeasurementEngine.metresPerPixel(
            for: calibration, imageSize: sheet.pageSize
        )
        let pixels = sheet.pageSize.pixelDistance(a, b)
        return .metres(pixels * mpp)
    }
}
