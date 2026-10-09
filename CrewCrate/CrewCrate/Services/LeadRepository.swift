import Foundation

nonisolated protocol LeadRepository: Sendable {
    func workspaces() async throws -> [LeadWorkspaceSummary]
    func workspace(id: UUID) async throws -> LeadWorkspaceSummary
    func leads(partnerID: UUID, search: String, status: LeadStatus?, offset: Int) async throws -> [LeadRecord]
    func leadsInImport(partnerID: UUID, importID: UUID?, offset: Int) async throws -> [LeadRecord]
    func imports(partnerID: UUID, offset: Int) async throws -> [LeadImportBatch]
    func activity(partnerID: UUID, offset: Int) async throws -> [LeadActivity]
    func preview(partnerID: UUID, document: CSVDocument, mapping: LeadColumnMapping) async throws -> LeadImportPreview
    func importLeads(partnerID: UUID, document: CSVDocument, mapping: LeadColumnMapping, expectedRevision: Int) async throws -> LeadImportBatch
    func setPermission(partnerID: UUID, leadID: UUID, permission: String, evidence: String, expectedRevision: Int) async throws -> LeadRecord
    func classify(partnerID: UUID, leadID: UUID, status: LeadStatus, expectedRevision: Int) async throws -> LeadRecord
}

extension LeadRepository {
    func leadsInImport(partnerID: UUID, importID: UUID?, offset: Int) async throws -> [LeadRecord] {
        guard let importID else { return try await leads(partnerID: partnerID, search: "", status: nil, offset: offset) }
        var matches: [LeadRecord] = []; var cursor = 0
        while matches.count < offset + 50 {
            let page = try await leads(partnerID: partnerID, search: "", status: nil, offset: cursor)
            matches += page.filter { $0.importID == importID }; cursor += page.count
            if page.count < 50 { break }
        }
        return Array(matches.dropFirst(offset).prefix(50))
    }
}
