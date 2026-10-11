import Foundation

nonisolated struct AuthenticatedIdentity: Decodable, Sendable {
    let userID: UUID
    let isOwner: Bool
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case isOwner = "is_owner"
    }
}


nonisolated struct CampaignWorkspace: Decodable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let status: String
}

nonisolated struct CampaignSummary: Decodable, Identifiable, Sendable {
    let id: UUID
    let partnerID: UUID
    let status: String
    let config: CampaignDetails
    enum CodingKeys: String, CodingKey { case id, status, config; case partnerID = "partner_id" }
}

nonisolated struct CampaignDetails: Codable, Sendable {
    var name = ""
    var offer = ""
    var aiName: String? = ""
    var aiBrief: String? = ""
    var qualification = ""
    var handoffEmail = ""
    enum CodingKeys: String, CodingKey {
        case name, offer, qualification
        case aiName = "ai_name", aiBrief = "ai_brief", handoffEmail = "handoff_email"
    }
}


nonisolated struct UserProfile: Decodable, Sendable {
    let id: UUID
    let email: String?
    let newEmail: String?
    let metadata: Metadata?
    nonisolated struct Metadata: Decodable, Sendable {
        let firstName: String?
        let lastName: String?
        enum CodingKeys: String, CodingKey { case firstName = "first_name", lastName = "last_name" }
    }
    enum CodingKeys: String, CodingKey { case id, email; case newEmail = "new_email", metadata = "user_metadata" }
}
