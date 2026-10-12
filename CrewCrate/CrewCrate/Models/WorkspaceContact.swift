import Foundation

nonisolated struct WorkspaceContact: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let phone: String
    let email: String
    let status: String
    let revision: Int
    let sms_permission: String
    let permission_evidence: String
    let opted_out: Bool
    let exclusion_reasons: [String]
    var permissionTitle: String {
        if opted_out || sms_permission == "revoked" { return "Opted out" }
        if status == "excluded" { return "Excluded" }
        if permission_evidence.hasPrefix("[TEST ONLY]") { return "Test contact only" }
        return sms_permission == "recorded" ? "Permission recorded" : "Needs permission review"
    }
}
nonisolated struct ContactReviewFields: Encodable, Sendable {
    var action = "record_permission"
    var evidence = ""
    var source = ""
    var consent_date = ""
    var country = "US"
    var attested = false
}
