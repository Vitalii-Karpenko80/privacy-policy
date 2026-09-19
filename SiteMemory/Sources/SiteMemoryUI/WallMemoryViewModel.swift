import Foundation
import SiteMemoryCore

#if canImport(SwiftUI)
import SwiftUI

/// Drives the "behind this wall" screen. It depends only on Core protocols, so
/// the same view model works with the file store standalone or FieldReport's
/// store when embedded — inject whichever conforms.
@MainActor
public final class WallMemoryViewModel: ObservableObject {
    @Published public private(set) var photos: [SitePhoto] = []
    @Published public private(set) var isLoading = false
    @Published public var errorMessage: String?

    private let wall: Wall
    private let roomName: String
    private let photoStore: PhotoStore
    private let unitSystem: UnitSystem

    public init(wall: Wall, roomName: String, photoStore: PhotoStore, unitSystem: UnitSystem) {
        self.wall = wall
        self.roomName = roomName
        self.photoStore = photoStore
        self.unitSystem = unitSystem
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await photoStore.photos(on: wall.id)
            // Fill in positions from each photo's reference scale for display.
            photos = loaded.map(PlanarMeasurementEngine.resolvingPositions(in:))
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Flattened, display-ready rows across all photos on this wall.
    public var rows: [Row] {
        photos.flatMap { photo in
            photo.annotations.map { annotation in
                Row(
                    id: annotation.id,
                    category: annotation.category,
                    detail: detail(for: annotation, capturedAt: photo.capturedAt),
                    isMachineSuggested: annotation.isMachineSuggested
                )
            }
        }
    }

    public struct Row: Identifiable {
        public let id: ID<HiddenObjectAnnotation>
        public let category: ObjectCategory
        public let detail: String
        public let isMachineSuggested: Bool
    }

    private func detail(for annotation: HiddenObjectAnnotation, capturedAt: Date) -> String {
        var parts: [String] = []
        if let position = annotation.position {
            parts.append("\(position.distanceFromLeft.formatted(unitSystem)) from left")
            parts.append("\(position.distanceFromTop.formatted(unitSystem)) down")
        }
        if let note = annotation.note, !note.isEmpty { parts.append(note) }
        parts.append(capturedAt.formatted(date: .abbreviated, time: .omitted))
        return parts.joined(separator: " · ")
    }
}
#endif
