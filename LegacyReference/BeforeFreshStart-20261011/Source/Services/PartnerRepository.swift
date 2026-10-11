import Foundation

/// Implement this interface with a server adapter later. Live authorization and
/// authoritative revisions/decision history must be enforced by that server.
nonisolated protocol PartnerRepository: Sendable {
    func list() async throws -> [PartnerWorkspace]
    func partner(id: UUID) async throws -> PartnerWorkspace
    func decide(id: UUID, expectedRevision: Int, action: ReviewAction, reason: String) async throws -> PartnerWorkspace
}
