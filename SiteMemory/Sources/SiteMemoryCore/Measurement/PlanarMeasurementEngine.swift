import Foundation

/// Turns taps on a flat photo into approximate real-world positions.
///
/// ## The MVP model
/// Given one `ReferenceScale` (two taps a known distance apart) and the source
/// `ImageSize`, we recover a single metres-per-pixel factor and read every
/// other tap's offset from the image edges off that factor.
///
/// ## Assumptions (and why they are acceptable for v1)
/// - The wall is photographed roughly **fronto-parallel**: the camera looks
///   straight at it. Oblique shots distort the scale across the frame.
/// - **Lens distortion is ignored.** Fine for the ±1–2 cm accuracy a
///   contractor needs to avoid drilling a pipe.
/// - The scale is **isotropic** — the same factor applies horizontally and
///   vertically. True only under the fronto-parallel assumption.
///
/// Every result carries a `confidence` so the UI can be honest about this. The
/// LiDAR/ARKit path (v2) replaces this engine with a real 3D solve and reports
/// high confidence; the API here does not change.
public enum PlanarMeasurementEngine {

    public enum MeasurementError: Error, Equatable {
        /// The two reference taps are (near) coincident, so no scale exists.
        case degenerateReference
    }

    /// Metres per source pixel implied by a reference scale.
    public static func metresPerPixel(
        for reference: ReferenceScale,
        imageSize: ImageSize
    ) throws -> Double {
        let pixels = imageSize.pixelDistance(reference.start, reference.end)
        guard pixels > 1e-6 else { throw MeasurementError.degenerateReference }
        return reference.realLength.metres / pixels
    }

    /// The planar position of a single point.
    public static func position(
        of point: NormalizedPoint,
        reference: ReferenceScale,
        imageSize: ImageSize
    ) throws -> PlanarPosition {
        let mpp = try metresPerPixel(for: reference, imageSize: imageSize)
        let left = Length.metres(point.x * imageSize.pixelWidth * mpp)
        let top = Length.metres(point.y * imageSize.pixelHeight * mpp)
        return PlanarPosition(
            distanceFromLeft: left,
            distanceFromTop: top,
            confidence: confidence(for: reference, imageSize: imageSize)
        )
    }

    /// Returns a copy of `photo` with `position` filled in on every annotation.
    /// A no-op (returns the input) when the photo has no reference scale yet.
    public static func resolvingPositions(in photo: SitePhoto) -> SitePhoto {
        guard let reference = photo.referenceScale else { return photo }
        var updated = photo
        updated.annotations = photo.annotations.map { annotation in
            var a = annotation
            a.position = try? position(
                of: annotation.region.anchorPoint,
                reference: reference,
                imageSize: photo.imageSize
            )
            return a
        }
        return updated
    }

    /// Heuristic confidence for the planar (non-LiDAR) path. A longer reference
    /// segment relative to the frame yields a more stable scale, so we reward
    /// it, capped well below 1 to signal "approximate".
    static func confidence(for reference: ReferenceScale, imageSize: ImageSize) -> Double {
        let refPixels = imageSize.pixelDistance(reference.start, reference.end)
        let diagonal = (imageSize.pixelWidth * imageSize.pixelWidth
                        + imageSize.pixelHeight * imageSize.pixelHeight).squareRoot()
        guard diagonal > 0 else { return 0 }
        let coverage = min(refPixels / diagonal, 1)
        return 0.55 + 0.3 * coverage // 0.55…0.85
    }
}
