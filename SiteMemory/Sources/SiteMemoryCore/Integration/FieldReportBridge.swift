import Foundation

// The single seam between SiteMemory and its host.
//
// SiteMemory never imports FieldReport. Instead the host conforms to these
// protocols, which is what makes the whole module dual-mode:
//
//   • Embedded in FieldReport — FieldReport implements `FieldReportLinking`
//     (to tie a jobsite to an existing report/invoice) and `ReportEmbedding`
//     (to drop a "Behind the walls" section into a generated PDF). It reuses
//     FieldReport's storage by also implementing the Store protocols.
//
//   • Standalone — the app provides its own trivial conformances (or none),
//     and SiteMemory runs on its own file-backed stores.
//
// This is the "Measure → Build → Photograph before closing → Report → Invoice
// → SiteMemory" chain expressed as a contract rather than a hard dependency.

/// Associates a SiteMemory project with entities owned by the host app.
public protocol FieldReportLinking: Sendable {
    /// Resolve (or create) the SiteMemory project that corresponds to a host
    /// project id. Lets a FieldReport report deep-link into wall memory.
    func siteMemoryProjectID(forHostProjectID hostID: String) async throws -> ID<Project>

    /// Called when the user starts an invoice/report in the host so SiteMemory
    /// can offer the relevant "before closing" photos as attachments.
    func hostDidBeginReport(hostReportID: String, projectID: ID<Project>) async throws
}

/// A render-ready snapshot of a wall's hidden objects, handed to the host to
/// embed in its PDF/report. Plain values only — no drawing, so Core stays UI-free.
public struct WallMemoryReport: Codable, Hashable, Sendable {
    public struct Entry: Codable, Hashable, Sendable {
        public let category: ObjectCategory
        public let positionSummary: String   // e.g. "320 mm from left · 1.18 m up"
        public let capturedAt: Date
        public let imageReference: ImageReference
        public let note: String?

        public init(
            category: ObjectCategory,
            positionSummary: String,
            capturedAt: Date,
            imageReference: ImageReference,
            note: String?
        ) {
            self.category = category
            self.positionSummary = positionSummary
            self.capturedAt = capturedAt
            self.imageReference = imageReference
            self.note = note
        }
    }

    public let wallName: String
    public let roomName: String
    public let entries: [Entry]

    public init(wallName: String, roomName: String, entries: [Entry]) {
        self.wallName = wallName
        self.roomName = roomName
        self.entries = entries
    }
}

/// The host implements this to receive report snapshots for embedding.
public protocol ReportEmbedding: Sendable {
    func embed(_ report: WallMemoryReport, intoHostReport hostReportID: String) async throws
}

/// Builds `WallMemoryReport`s from stored data. Concrete, lives in Core because
/// it is pure assembly over the model — no host or framework needed.
public struct WallMemoryReportBuilder: Sendable {
    private let unitSystem: UnitSystem

    public init(unitSystem: UnitSystem) {
        self.unitSystem = unitSystem
    }

    public func makeReport(wall: Wall, roomName: String, photos: [SitePhoto]) -> WallMemoryReport {
        let entries = photos.flatMap { photo in
            photo.annotations.map { annotation in
                WallMemoryReport.Entry(
                    category: annotation.category,
                    positionSummary: summary(for: annotation.position),
                    capturedAt: photo.capturedAt,
                    imageReference: photo.imageReference,
                    note: annotation.note
                )
            }
        }
        return WallMemoryReport(wallName: wall.name, roomName: roomName, entries: entries)
    }

    private func summary(for position: PlanarPosition?) -> String {
        guard let position else { return "position not measured" }
        let left = position.distanceFromLeft.formatted(unitSystem)
        let top = position.distanceFromTop.formatted(unitSystem)
        return "\(left) from left · \(top) down"
    }
}
