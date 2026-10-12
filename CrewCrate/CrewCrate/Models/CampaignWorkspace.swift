import Foundation

nonisolated struct CampaignSettings: Codable, Sendable, Equatable {
    var name = ""
    var offer = ""
    var ai_brief: String? = "Use a warm, professional tone. Keep messages short and clear."
    var ai_name: String? = "Emma"
    var message_template = ""
    var qualification = ""
    var handoff_email = ""
    var start_date: String?
    var end_date: String?
    var time_zone = "America/Chicago"
    var start_minute: Int? = 0
    var end_minute: Int? = 0
    var start_hour = 9
    var end_hour = 17
    var daily_limit = 25
    var follow_up_limit = 1
    var lead_ids: [UUID] = []
}

nonisolated struct WorkspaceCampaign: Codable, Identifiable, Sendable {
    let id: UUID
    let partner_id: UUID
    let status: String
    let revision: Int
    let config: CampaignSettings
    let blockers: [String]
    let recipient_count: Int
    let needs_recheck: Bool
    let owner_hold: Bool
    let messaging_connected: Bool
    let sending_enabled: Bool

    var statusTitle: String {
        switch status {
        case "draft": "Draft"
        case "ready_to_connect": "Prepared"
        case "paused": "Paused"
        case "archived": "Archived"
        default: status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
    var isEditable: Bool { !owner_hold && !["paused", "archived"].contains(status) }
}

nonisolated struct PracticeConversation: Codable, Identifiable, Sendable {
    let id: UUID
    let revision: Int
    let status: String
    let ai_name: String
    let messages: [PracticeMessage]
    let decisions: [PracticeDecision]
}
nonisolated struct PracticeMessage: Codable, Identifiable, Sendable {
    let id: UUID
    let role: String
    let text: String
    let request_id: UUID?
}
nonisolated struct PracticeDecision: Codable, Identifiable, Sendable {
    let id: UUID
    let decision: String
    let reason: String
    let handoff_summary: String
    let strong_response: Bool?
    let signal_reason: String?
    let signal_evidence: String?
}

nonisolated struct ContactUpload: Sendable {
    let filename: String
    let data: Data
}
nonisolated struct UploadColumns: Decodable, Sendable {
    let columns: [String]
    let sheets: [String]
    let selected_sheet: String?
}
nonisolated struct UploadPreview: Decodable, Sendable {
    let partner_revision: Int
    let total_rows: Int
    let imported: Int
    let duplicates: Int
    let invalid: Int
    let issues: [UploadIssue]
    var eligible_count: Int? = nil
    var excluded_count: Int? = nil
    var contacts: [UploadPreviewContact]? = nil
    var contacts_truncated: Bool? = nil
    let issues_truncated: Bool
}
nonisolated struct UploadPreviewContact: Decodable, Sendable, Identifiable {
    var id: String { phone }
    let row_number: Int
    let phone: String
    let name: String
    let sms_permission: String
    let opted_out: Bool
    let eligible_for_sms: Bool
    let exclusion_reasons: [String]
}
nonisolated struct UploadIssue: Decodable, Sendable {
    let row_number: Int
    let kind: String
    let detail: String
}
nonisolated struct UploadMapping: Sendable, Equatable {
    var phone = ""
    var name = ""
    var email = ""
    var sheet = ""
    var permission = ""
    var evidence = ""
    var optout = ""
    var permissionAttested = false
    var isValid: Bool {
        let selected = [phone, name, email, permission, evidence, optout].filter { !$0.isEmpty }
        return !phone.isEmpty && Set(selected).count == selected.count
    }
}
