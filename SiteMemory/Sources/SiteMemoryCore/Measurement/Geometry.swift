import Foundation

/// A point in normalized image coordinates: `(0,0)` top-left, `(1,1)`
/// bottom-right. Normalizing decouples stored annotations from the pixel
/// dimensions of whatever image the user actually tapped on (thumbnail vs.
/// full-res), which is exactly what a two-tap capture flow needs.
public struct NormalizedPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// The pixel dimensions of the source image the taps were made on.
public struct ImageSize: Codable, Hashable, Sendable {
    public var pixelWidth: Double
    public var pixelHeight: Double

    public init(pixelWidth: Double, pixelHeight: Double) {
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    /// Pixel distance between two normalized points, honouring aspect ratio.
    func pixelDistance(_ a: NormalizedPoint, _ b: NormalizedPoint) -> Double {
        let dx = (a.x - b.x) * pixelWidth
        let dy = (a.y - b.y) * pixelHeight
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// A user-placed scale reference: two points whose real-world separation is
/// known (e.g. "these two taps span the 4.2 m width of the wall").
///
/// This is the whole trick of the MVP: one known distance in the photo turns
/// every other tap into an approximate real measurement, with no LiDAR.
public struct ReferenceScale: Codable, Hashable, Sendable {
    public var start: NormalizedPoint
    public var end: NormalizedPoint
    public var realLength: Length

    public init(start: NormalizedPoint, end: NormalizedPoint, realLength: Length) {
        self.start = start
        self.end = end
        self.realLength = realLength
    }
}

/// An approximate real-world position of an object on the wall plane,
/// expressed as offsets from the surface edges — the numbers a tiler or
/// electrician actually wants ("320 mm from the left edge").
public struct PlanarPosition: Codable, Hashable, Sendable {
    public var distanceFromLeft: Length
    public var distanceFromTop: Length
    /// 0…1 self-reported confidence. Lower it as the source photo departs from
    /// the fronto-parallel assumption; a LiDAR-derived position reports ~1.
    public var confidence: Double

    public init(distanceFromLeft: Length, distanceFromTop: Length, confidence: Double) {
        self.distanceFromLeft = distanceFromLeft
        self.distanceFromTop = distanceFromTop
        self.confidence = confidence
    }
}
