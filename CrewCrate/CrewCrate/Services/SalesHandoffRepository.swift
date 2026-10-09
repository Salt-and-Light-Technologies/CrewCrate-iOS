import Foundation
nonisolated protocol SalesHandoffRepository: Sendable {
    func handoffEmails(partnerID: UUID) async throws -> [String]
    func addHandoffEmail(partnerID: UUID, email: String) async throws -> [String]
}
nonisolated struct SalesHandoffDirectory: Decodable { let emails: [String] }
extension APILeadRepository: SalesHandoffRepository {
    func handoffEmails(partnerID: UUID) async throws -> [String] {
        try JSONDecoder().decode(SalesHandoffDirectory.self, from: await request("v1/partners/\(partnerID.uuidString)/handoff-emails")).emails
    }
    func addHandoffEmail(partnerID: UUID, email: String) async throws -> [String] {
        let body = try JSONSerialization.data(withJSONObject: ["email": email])
        return try JSONDecoder().decode(SalesHandoffDirectory.self, from: await request("v1/partners/\(partnerID.uuidString)/handoff-emails", method: "POST", body: body, contentType: "application/json")).emails
    }
}
