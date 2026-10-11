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


nonisolated struct AITestConversation: Decodable, Identifiable, Sendable {
    let id: UUID
    let revision: Int
    let status: String
    let aiName: String
    let messages: [AITestMessage]
    let decisions: [AITestDecision]
    var isActive: Bool { status == "active" }
    enum CodingKeys: String, CodingKey { case id, revision, status, messages, decisions; case aiName = "ai_name" }
}

nonisolated struct AITestMessage: Decodable, Identifiable, Sendable {
    let id: UUID
    let role: String
    let text: String
    let timestamp: String
}

nonisolated struct AITestDecision: Decodable, Identifiable, Sendable {
    let id: UUID
    let decision: String
    let reason: String
    let handoffSummary: String
    var label: String {
        switch decision {
        case "handoff": "Simulated sales handoff"
        case "opt_out": "Simulated opt-out · outreach stopped"
        case "end_outreach": "Simulated campaign outreach ended"
        default: "Continue conversation"
        }
    }
    enum CodingKeys: String, CodingKey { case id, decision, reason; case handoffSummary = "handoff_summary" }
}
