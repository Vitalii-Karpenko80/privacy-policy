import Foundation
import SiteMemoryCore

#if canImport(ARKit)
import ARKit

/// ARKit-backed spatial anchoring: the v2 capability that turns a finished
/// wall back into an "x-ray" by relocalizing against a saved `ARWorldMap` and
/// projecting the recorded hidden objects onto the live camera.
///
/// This is a structural stub: the session wiring and math are marked with
/// `TODO`s but the surface is the real contract from `SiteMemoryCore`, so the
/// app and its tests can already depend on it and the MVP can ship without it.
public final class ARSpatialAnchoring: SpatialAnchoring, @unchecked Sendable {
    private let session: ARSession

    public init(session: ARSession = ARSession()) {
        self.session = session
    }

    public var capability: SpatialCapability {
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            return .lidar
        }
        return ARWorldTrackingConfiguration.isSupported ? .worldTracking : .unavailable
    }

    public func captureAnchor(for wall: ID<Wall>) async throws -> SpatialAnchor {
        // TODO: run the session until tracking is `.normal`, then
        // `session.getCurrentWorldMap` and archive it with NSKeyedArchiver.
        let worldMap = try await currentWorldMapData()
        return SpatialAnchor(
            wallID: wall,
            worldMapData: worldMap,
            transform: Self.identityTransform
        )
    }

    public func relocalize(
        to anchor: SpatialAnchor,
        objects: [HiddenObjectAnnotation]
    ) -> AsyncThrowingStream<[ProjectedObject], Error> {
        AsyncThrowingStream { continuation in
            // TODO: decode `anchor.worldMapData` into an `ARWorldMap`, set it as
            // the session's `initialWorldMap`, and on every `ARFrame` project
            // each object's 3D position via `frame.camera.projectPoint` to fill
            // `screenPoint`. For now, emit the objects as off-screen so the UI
            // can render its "acquiring…" state against the real type.
            let initial = objects.map {
                ProjectedObject(annotationID: $0.id, category: $0.category, screenPoint: nil)
            }
            continuation.yield(initial)
            continuation.finish()
        }
    }

    private func currentWorldMapData() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            session.getCurrentWorldMap { map, error in
                if let error { continuation.resume(throwing: error); return }
                guard let map else {
                    continuation.resume(throwing: StoreError.underlying("no world map"))
                    return
                }
                do {
                    let data = try NSKeyedArchiver.archivedData(
                        withRootObject: map, requiringSecureCoding: true
                    )
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static let identityTransform: [Double] = [
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    ]
}
#endif
