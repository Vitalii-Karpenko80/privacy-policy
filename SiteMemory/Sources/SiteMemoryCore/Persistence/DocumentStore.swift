import Foundation

/// Stores project documents (PDF drawings), the plan sheets calibrated from
/// them, and the photo/wall pins placed on those sheets — metadata plus the
/// PDF bytes. Kept separate from `ProjectStore`/`PhotoStore` so a host can
/// adopt document support incrementally.
public protocol DocumentStore: Sendable {
    // Documents
    func documents(in project: ID<Project>) async throws -> [ProjectDocument]
    func save(_ document: ProjectDocument) async throws
    func delete(_ id: ID<ProjectDocument>) async throws

    /// Persist PDF bytes locally and return the reference to store on the
    /// `ProjectDocument`. Bytes never leave the app container.
    func storeDocumentData(_ data: Data, suggestedName: String) async throws -> DocumentReference
    func documentData(for reference: DocumentReference) async throws -> Data

    // Plan sheets
    func sheets(in document: ID<ProjectDocument>) async throws -> [PlanSheet]
    func save(_ sheet: PlanSheet) async throws
    func delete(_ id: ID<PlanSheet>) async throws

    // Placements
    func placements(on sheet: ID<PlanSheet>) async throws -> [PlanPlacement]
    func save(_ placement: PlanPlacement) async throws
    func delete(_ id: ID<PlanPlacement>) async throws
}
