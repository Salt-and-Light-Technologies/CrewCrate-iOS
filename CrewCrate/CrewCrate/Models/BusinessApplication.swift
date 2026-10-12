import Foundation

nonisolated struct BusinessApplication: Codable, Identifiable, Sendable {
    let id: UUID
    let business_name: String
    let contact_name: String
    let email: String
    let phone: String
    let referral: String
    let status: String
    let revision: Int
    let partner_id: UUID?
    let review_note: String
}

nonisolated struct BusinessApplicationDraft: Codable, Sendable {
    var business_name = ""
    var contact_name = ""
    var email = ""
    var phone = ""
    var referral = ""

    var isComplete: Bool {
        business_name.count <= 160 && contact_name.count <= 200 && email.count <= 320 &&
        phone.count <= 40 && referral.count <= 2000 &&
        !business_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !contact_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.trimmingCharacters(in: .whitespacesAndNewlines)
            .range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil &&
        (7...15).contains(phone.filter { $0.isASCII && $0.isNumber }.count) &&
        phone.allSatisfy { "+0123456789 ()-.".contains($0) }
    }
}

nonisolated struct BusinessSummary: Decodable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let status: String
    let revision: Int
    var onboarding: BusinessProfileFields? = nil
    var access_approved: Bool? = nil
    var member_role: String? = nil
}
