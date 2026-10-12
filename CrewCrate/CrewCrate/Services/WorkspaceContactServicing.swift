import Foundation

nonisolated protocol WorkspaceContactServicing: Sendable {
    func contacts(business: UUID, campaign: UUID, search: String, offset: Int) async throws -> [WorkspaceContact]
    func reviewContact(business: UUID, contact: WorkspaceContact, fields: ContactReviewFields) async throws -> WorkspaceContact
}
extension SupabaseSession: WorkspaceContactServicing {
    func contacts(business: UUID, campaign: UUID, search: String, offset: Int) async throws -> [WorkspaceContact] {
        try await apiRequest("v1/partners/\(business)/leads", query: [
            URLQueryItem(name: "campaign_id", value: campaign.uuidString),
            URLQueryItem(name: "search", value: search), URLQueryItem(name: "limit", value: "250"),
            URLQueryItem(name: "offset", value: String(offset))])
    }
    func reviewContact(business: UUID, contact: WorkspaceContact, fields: ContactReviewFields) async throws -> WorkspaceContact {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(fields)) as! [String: Any]
        object["expected_revision"] = contact.revision
        return try await apiRequest("v1/partners/\(business)/leads/\(contact.id)/contact-review", method: "POST",
            body: JSONSerialization.data(withJSONObject: object))
    }
}
