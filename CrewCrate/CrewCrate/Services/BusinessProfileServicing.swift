import Foundation

nonisolated protocol BusinessProfileServicing: Sendable {
    func businessProfile(id: UUID) async throws -> BusinessProfileRecord
    func saveBusinessProfile(id: UUID, revision: Int, fields: BusinessProfileFields) async throws -> BusinessProfileRecord
}
extension SupabaseSession: BusinessProfileServicing {
    func businessProfile(id: UUID) async throws -> BusinessProfileRecord {
        try await apiRequest("v1/partners/\(id)")
    }
    func saveBusinessProfile(id: UUID, revision: Int, fields: BusinessProfileFields) async throws -> BusinessProfileRecord {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(fields)) as! [String: Any]
        object["expected_revision"] = revision
        return try await apiRequest("v1/partners/\(id)/business", method: "PUT", body: JSONSerialization.data(withJSONObject: object))
    }
}
