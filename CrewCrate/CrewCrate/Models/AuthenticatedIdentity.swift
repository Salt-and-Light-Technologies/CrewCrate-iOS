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
    let revision: Int
    let blockers: [String]?
    let ownerHold: Bool?
    let recipientCount: Int?
    enum CodingKeys: String, CodingKey { case id, status, config, revision, blockers; case ownerHold = "owner_hold", recipientCount = "recipient_count"; case partnerID = "partner_id" }
}

nonisolated struct CampaignDetails: Codable, Sendable, Equatable {
    var name = ""
    var offer = ""
    var aiName: String? = ""
    var aiBrief: String? = ""
    var qualification = ""
    var handoffEmail = ""
    var messageTemplate: String = ""
    var timeZone: String = "America/Chicago"
    var startMinute: Int? = nil
    var endMinute: Int? = nil
    var startHour: Int = 9
    var endHour: Int = 17
    var dailyLimit: Int = 25
    var followUpLimit: Int = 1
    var leadIDs: [UUID] = []
    init() {}
    enum CodingKeys: String, CodingKey {
        case name = "name"
        case offer = "offer"
        case aiName = "ai_name"
        case aiBrief = "ai_brief"
        case qualification = "qualification"
        case handoffEmail = "handoff_email"
        case messageTemplate = "message_template"
        case timeZone = "time_zone"
        case startMinute = "start_minute"
        case endMinute = "end_minute"
        case startHour = "start_hour"
        case endHour = "end_hour"
        case dailyLimit = "daily_limit"
        case followUpLimit = "follow_up_limit"
        case leadIDs = "lead_ids"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        offer = try values.decodeIfPresent(String.self, forKey: .offer) ?? ""
        aiName = try values.decodeIfPresent(String.self, forKey: .aiName)
        aiBrief = try values.decodeIfPresent(String.self, forKey: .aiBrief)
        qualification = try values.decodeIfPresent(String.self, forKey: .qualification) ?? ""
        handoffEmail = try values.decodeIfPresent(String.self, forKey: .handoffEmail) ?? ""
        messageTemplate = try values.decodeIfPresent(String.self, forKey: .messageTemplate) ?? ""
        timeZone = try values.decodeIfPresent(String.self, forKey: .timeZone) ?? "America/Chicago"
        startMinute = try values.decodeIfPresent(Int.self, forKey: .startMinute)
        endMinute = try values.decodeIfPresent(Int.self, forKey: .endMinute)
        startHour = try values.decodeIfPresent(Int.self, forKey: .startHour) ?? 9
        endHour = try values.decodeIfPresent(Int.self, forKey: .endHour) ?? 17
        dailyLimit = try values.decodeIfPresent(Int.self, forKey: .dailyLimit) ?? 25
        followUpLimit = try values.decodeIfPresent(Int.self, forKey: .followUpLimit) ?? 1
        leadIDs = try values.decodeIfPresent([UUID].self, forKey: .leadIDs) ?? []
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


nonisolated struct BusinessDetails: Codable, Sendable {
    var business_name = ""
    var website = ""
    var industry = ""
    var services = ""
    var service_area = ""
    var time_zone = ""
    var ai_boundaries = ""
}

nonisolated struct BusinessWorkspace: Decodable, Identifiable, Sendable {
    let id: UUID
    let revision: Int
    let onboarding: BusinessDetails
}

nonisolated struct ContactFile: Sendable {
    let name: String
    let data: Data
}
nonisolated struct ImportColumns: Decodable, Sendable {
    let columns: [String]
    let sheets: [String]
    let selected_sheet: String?
}
nonisolated struct ContactMapping: Sendable, Equatable {
    var phone = ""
    var name = ""
    var email = ""
    var sheet = ""
    var permission = ""
    var evidence = ""
    var optout = ""
    var test = ""
    var permissionAttested = false
}
nonisolated struct ContactPreview: Decodable, Sendable {
    let partner_revision: Int
    let total_rows: Int
    let imported: Int
    let duplicates: Int
    let invalid: Int
    let issues: [Issue]
    let issues_truncated: Bool
    nonisolated struct Issue: Decodable, Sendable { let row_number: Int; let kind: String; let detail: String }
}


nonisolated struct CampaignLead: Decodable, Identifiable, Sendable {
    let id: UUID
    let import_id: UUID
    let name: String
    let phone: String
    let email: String
    let status: String
    let revision: Int
    let sms_permission: String
    let permission_evidence: String
    let opted_out: Bool
    let eligible_for_sms: Bool
    let exclusion_reasons: [String]
}
nonisolated struct LeadBatch: Decodable, Identifiable, Sendable {
    let id: UUID
    let file_name: String
    let total_rows: Int
}
nonisolated struct LeadReview: Encodable, Sendable {
    let expected_revision: Int
    let action: String
    let evidence: String
    let source: String
    let consent_date: String
    let country: String
    let attested: Bool
}
nonisolated struct RecipientSelectionResult: Decodable, Sendable {
    let campaign: CampaignSummary
    let removed_count: Int
}
