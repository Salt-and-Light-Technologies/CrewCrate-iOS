import Foundation

nonisolated enum CampaignStatus: String, Codable, Sendable {
    case draft, readyToConnect = "ready_to_connect", paused, archived
    var title: String {
        switch self { case .draft: "Draft"; case .readyToConnect: "Ready to connect"; case .paused: "Paused"; case .archived: "Archived" }
    }
}
nonisolated struct CampaignConfig: Codable, Equatable, Sendable {
    var name = ""
    var offer = ""
    var aiBrief: String?
    var aiName: String?
    var messageTemplate = ""
    var qualification = ""
    var handoffEmail = ""
    var timeZone = TimeZone.current.identifier
    var startMinute: Int?
    var endMinute: Int?
    var startHour = 9
    var endHour = 17
    var dailyLimit = 25
    var followUpLimit = 1
    var leadIDs: [UUID] = []
}
nonisolated struct CampaignRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let partnerID: UUID
    var status: CampaignStatus = .draft
    var revision = 1
    var config: CampaignConfig
    var updatedAt: Date = .now
    var blockers: [String] = []
    var recipientCount = 0
    var needsRecheck = false
    var ownerHold = false
    var preparedPartnerRevision: Int?
    var preparedLeadRevisions: [UUID: Int] = [:]
}
nonisolated struct CampaignActivity: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let action: String
    let detail: String
    let actorName: String
    let timestamp: Date
}
nonisolated enum ConversationStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case new, interested, appointment, handoff, closed
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}
nonisolated struct ConversationRecord: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let campaignID: UUID
    let leadID: UUID
    var status: ConversationStatus = .new
    var revision = 0
    var updatedAt: Date = .now
}
nonisolated struct ConversationNote: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let status: ConversationStatus
    let note: String
    let actorName: String
    let timestamp: Date
}
nonisolated enum CampaignError: LocalizedError {
    case invalid(String), conflict, missing, locked
    var errorDescription: String? {
        switch self {
        case .invalid(let detail): detail
        case .conflict: "This record changed. Refresh before saving."
        case .missing: "This campaign or conversation is unavailable."
        case .locked: "The partner or campaign is paused or archived."
        }
    }
}
nonisolated enum CampaignValidation {
    static func draftIssues(_ config: CampaignConfig) -> [String] {
        var issues: [String] = []
        if config.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || config.name.count > 160 { issues.append("Name the campaign using up to 160 characters.") }
        if config.messageTemplate.count > 480 { issues.append("Keep the message draft within 480 characters.") }
        if config.offer.count > 2000 || config.qualification.count > 2000 { issues.append("Keep offer and qualification notes within 2,000 characters.") }
        if config.dailyLimit < 1 { issues.append("Daily contact limit must be a positive whole number.") }
        if !(0...3).contains(config.followUpLimit) { issues.append("Choose zero to three follow-ups.") }
        if !(9...17).contains(config.startHour) || !(9...17).contains(config.endHour) { issues.append("Plan sending between 9:00 and 17:00.") }
        if !(0...59).contains(config.startMinute ?? 0) || !(0...59).contains(config.endMinute ?? 0) || (config.endHour == 17 && (config.endMinute ?? 0) > 0) { issues.append("Choose valid times between 9:00 AM and 5:00 PM.") }
        if config.leadIDs.count > 500 || Set(config.leadIDs).count != config.leadIDs.count { issues.append("Choose up to 500 distinct recipients.") }
        return issues
    }
    static func readiness(_ config: CampaignConfig) -> [String] {
        var issues = draftIssues(config)
        if config.offer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("Describe the recovery offer.") }
        if config.qualification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("Define qualification and handoff rules.") }
        if !OnboardingValidation.email(config.handoffEmail) { issues.append("Provide a valid handoff email.") }
        if TimeZone(identifier: config.timeZone) == nil { issues.append("Choose a valid IANA time zone.") }
        if config.startHour * 60 + (config.startMinute ?? 0) >= config.endHour * 60 + (config.endMinute ?? 0) { issues.append("End the sending window after it starts.") }
        if config.leadIDs.isEmpty { issues.append("Choose campaign recipients.") }
        return issues
    }
}
