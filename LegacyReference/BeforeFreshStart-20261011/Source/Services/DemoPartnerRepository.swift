import Foundation

actor DemoPartnerRepository: PartnerRepository {
    private var partners: [UUID: PartnerWorkspace]
    private var leadRecords: [UUID: [LeadRecord]] = [:]
    private var leadImports: [UUID: [LeadImportBatch]] = [:]
    private var leadActivities: [UUID: [LeadActivity]] = [:]
    private var campaignRecords: [UUID: CampaignRecord] = [:]
    private var campaignActivities: [UUID: [CampaignActivity]] = [:]
    private var conversationRecords: [UUID: [ConversationRecord]] = [:]
    private var conversationNotes: [UUID: [ConversationNote]] = [:]
    init(partners: [PartnerWorkspace] = DemoPartnerFixtures.make(), campaignDemo: Bool = false) {
        self.partners = Dictionary(uniqueKeysWithValues: partners.map { ($0.id, $0) })
        if campaignDemo, var sample = partners.first {
            sample.status = .pilotApproved; sample.onboarding.goal = .handoff
            let batch = LeadImportBatch(id: UUID(), fileName: "campaign-sample.csv", totalRows: 3, imported: 3, duplicates: 0, invalid: 0, timestamp: .now)
            var allowed = LeadRecord(id: UUID(), importID: batch.id, name: "Sample eligible contact", phone: "12025550101", email: "sample@example.com", status: .eligible)
            allowed.smsPermission = "recorded"; allowed.permissionEvidence = "Sample permission evidence for demonstration only"
            let unknown = LeadRecord(id: UUID(), importID: batch.id, name: "Sample permission pending", phone: "12025550102", email: "pending@example.com", status: .eligible)
            var excluded = LeadRecord(id: UUID(), importID: batch.id, name: "Sample opted-out contact", phone: "12025550103", email: "excluded@example.com", status: .excluded)
            excluded.smsPermission = "revoked"; excluded.permissionEvidence = "Sample opt-out"; excluded.optedOut = true
            leadRecords[sample.id] = [allowed, unknown, excluded]; leadImports[sample.id] = [batch]
            sample.onboarding.importSummary = ImportSummary(fileName: batch.fileName, totalRows: 3, validContacts: 3, duplicateContacts: 0, invalidContacts: 0, phoneColumn: "Phone")
            self.partners[sample.id] = sample
        }
    }
    func list() async throws -> [PartnerWorkspace] {
        partners.values.sorted { $0.updatedAt > $1.updatedAt }
    }
    func partner(id: UUID) async throws -> PartnerWorkspace {
        guard let value = partners[id] else { throw PartnerRepositoryError.notFound }
        return value
    }
    func decide(id: UUID, expectedRevision: Int, action: ReviewAction, reason: String) async throws -> PartnerWorkspace {
        var value = try await partner(id: id)
        guard value.revision == expectedRevision else { throw PartnerRepositoryError.conflict }
        let note = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if action == .requestChanges || action == .pause {
            guard note.count >= 5 else { throw PartnerRepositoryError.reasonRequired }
        }
        let previous = value.status
        switch action {
        case .approve:
            guard previous == .submitted else { throw PartnerRepositoryError.invalidTransition }
            guard value.missingLaunchRequirements.isEmpty else { throw PartnerRepositoryError.missingRequirements }
            value.status = .pilotApproved
        case .requestChanges:
            guard value.canRequestChanges else { throw PartnerRepositoryError.invalidTransition }
            value.status = .changesRequested
        case .pause:
            guard previous != .paused else { throw PartnerRepositoryError.invalidTransition }
            value.pausedFrom = previous; value.status = .paused
        case .resume:
            guard previous == .paused, let restored = value.pausedFrom, restored != .paused else { throw PartnerRepositoryError.invalidTransition }
            value.status = restored; value.pausedFrom = nil
        }
        value.revision += 1; value.updatedAt = .now
        value.history.append(ReviewEvent(id: UUID(), action: action, previousStatus: previous, resultingStatus: value.status, actorName: "You (demo owner)", reason: note, timestamp: value.updatedAt))
        partners[id] = value
        return value
    }
}

extension DemoPartnerRepository: LeadRepository {
    func workspaces() async throws -> [LeadWorkspaceSummary] {
        partners.values.sorted { $0.updatedAt > $1.updatedAt }.map { summary($0) }
    }
    private func summary(_ partner: PartnerWorkspace) -> LeadWorkspaceSummary {
        let records = leadRecords[partner.id, default: []]
        return LeadWorkspaceSummary(id: partner.id, name: partner.name, status: partner.status, revision: partner.revision, totalLeads: records.count, importCount: leadImports[partner.id, default: []].count, counts: Dictionary(grouping: records, by: \.status).mapValues { $0.count })
    }
    func workspace(id: UUID) async throws -> LeadWorkspaceSummary {
        guard let partner = partners[id] else { throw LeadRepositoryError.missing }
        return summary(partner)
    }
    func leads(partnerID: UUID, search: String, status: LeadStatus?, offset: Int) async throws -> [LeadRecord] {
        guard partners[partnerID] != nil else { throw LeadRepositoryError.missing }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = leadRecords[partnerID, default: []].filter {
            (status == nil || $0.status == status) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.email.localizedCaseInsensitiveContains(query) || $0.phone.contains(query))
        }.sorted { $0.id.uuidString < $1.id.uuidString }
        return Array(filtered.dropFirst(max(0, offset)).prefix(50))
    }
    func imports(partnerID: UUID, offset: Int) async throws -> [LeadImportBatch] {
        guard partners[partnerID] != nil else { throw LeadRepositoryError.missing }
        return Array(leadImports[partnerID, default: []].reversed().dropFirst(max(0, offset)).prefix(50))
    }
    func activity(partnerID: UUID, offset: Int) async throws -> [LeadActivity] {
        guard partners[partnerID] != nil else { throw LeadRepositoryError.missing }
        return Array(leadActivities[partnerID, default: []].reversed().dropFirst(max(0, offset)).prefix(50))
    }
    func preview(partnerID: UUID, document: CSVDocument, mapping: LeadColumnMapping) async throws -> LeadImportPreview {
        guard let partner = partners[partnerID] else { throw LeadRepositoryError.missing }
        guard summary(partner).canImport else { throw LeadRepositoryError.locked }
        return try LeadImportAnalyzer.analyze(document, mapping: mapping, existing: Set(leadRecords[partnerID, default: []].map(\.phone)), revision: partner.revision).0
    }
    func importLeads(partnerID: UUID, document: CSVDocument, mapping: LeadColumnMapping, expectedRevision: Int) async throws -> LeadImportBatch {
        guard var partner = partners[partnerID] else { throw LeadRepositoryError.missing }
        guard partner.revision == expectedRevision else { throw LeadRepositoryError.conflict }
        guard summary(partner).canImport else { throw LeadRepositoryError.locked }
        let (preview, contacts) = try LeadImportAnalyzer.analyze(document, mapping: mapping, existing: Set(leadRecords[partnerID, default: []].map(\.phone)), revision: partner.revision)
        let batch = LeadImportBatch(id: UUID(), fileName: document.fileName, totalRows: preview.totalRows, imported: preview.imported, duplicates: preview.duplicates, invalid: preview.invalid, timestamp: .now)
        leadImports[partnerID, default: []].append(batch)
        leadRecords[partnerID, default: []] += contacts.map { LeadRecord(id: UUID(), importID: batch.id, name: $0.0, phone: $0.1, email: $0.2) }
        partner.readiness = LaunchReadiness()
        partner.onboarding.importSummary = ImportSummary(fileName: document.fileName, totalRows: batch.totalRows, validContacts: batch.imported, duplicateContacts: batch.duplicates, invalidContacts: batch.invalid, phoneColumn: document.headers[mapping.phone])
        partner.revision += 1; partner.updatedAt = .now
        partners[partnerID] = partner
        leadActivities[partnerID, default: []].append(LeadActivity(id: UUID(), action: "Leads imported", actorName: "You (demo)", detail: "\(batch.imported) imported; \(batch.duplicates) duplicates; \(batch.invalid) invalid", timestamp: batch.timestamp))
        return batch
    }
    func classify(partnerID: UUID, leadID: UUID, status: LeadStatus, expectedRevision: Int) async throws -> LeadRecord {
        guard var partner = partners[partnerID], let index = leadRecords[partnerID]?.firstIndex(where: { $0.id == leadID }) else { throw LeadRepositoryError.missing }
        guard partner.status != .paused else { throw LeadRepositoryError.locked }
        var lead = leadRecords[partnerID]![index]
        guard lead.revision == expectedRevision else { throw LeadRepositoryError.conflict }
        let automaticStatus: LeadStatus? = lead.optedOut || lead.smsPermission == "revoked" ? .excluded : (lead.smsPermission == "recorded" ? .eligible : nil)
        if let automaticStatus, status != automaticStatus { throw CampaignError.invalid("Review status is determined by this contact's SMS permission and opt-out.") }
        let previous = lead.status
        lead.status = status; lead.revision += 1; leadRecords[partnerID]![index] = lead
        partner.revision += 1; partner.updatedAt = .now; partners[partnerID] = partner
        leadActivities[partnerID, default: []].append(LeadActivity(id: UUID(), action: "Lead status changed", actorName: "You (demo)", detail: "\(lead.name.isEmpty ? lead.phone : lead.name): \(previous.title) → \(status.title)", timestamp: .now))
        return lead
    }
}


extension DemoPartnerRepository {
    func setPermission(partnerID: UUID, leadID: UUID, permission: String, evidence: String, expectedRevision: Int) async throws -> LeadRecord {
        guard var partner = partners[partnerID], let index = leadRecords[partnerID]?.firstIndex(where: { $0.id == leadID }) else { throw LeadRepositoryError.missing }
        guard partner.status != .paused else { throw LeadRepositoryError.locked }
        var lead = leadRecords[partnerID]![index]
        guard lead.revision == expectedRevision else { throw LeadRepositoryError.conflict }
        guard ["recorded", "revoked"].contains(permission), evidence.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8, evidence.count <= 2000 else { throw CampaignError.invalid("Add an evidence reference or revocation reason of 8 to 2,000 characters.") }
        guard !lead.optedOut || permission == "revoked" else { throw CampaignError.invalid("Opted-out contacts cannot be re-enabled here.") }
        lead.smsPermission = permission; lead.permissionEvidence = evidence.trimmingCharacters(in: .whitespacesAndNewlines)
        if permission == "revoked" { lead.optedOut = true }
        lead.status = permission == "recorded" && !lead.optedOut ? .eligible : .excluded
        lead.revision += 1; leadRecords[partnerID]![index] = lead
        partner.revision += 1; partner.updatedAt = .now; partners[partnerID] = partner
        leadActivities[partnerID, default: []].append(LeadActivity(id: UUID(), action: "SMS permission updated", actorName: "You (demo)", detail: "\(lead.name): \(permission)", timestamp: .now))
        return lead
    }
}

extension DemoPartnerRepository: CampaignRepository {
    private func campaignSnapshot(_ value: CampaignRecord) throws -> CampaignRecord {
        guard let partner = partners[value.partnerID] else { throw CampaignError.missing }
        var campaign = value
        var blockers = CampaignValidation.readiness(value.config)
        if partner.status != .pilotApproved { blockers.append("Partner setup must be pilot approved.") }
        blockers += partner.missingLaunchRequirements
        let records = leadRecords[partner.id, default: []].filter { value.config.leadIDs.contains($0.id) }
        if records.count != Set(value.config.leadIDs).count { blockers.append("Some recipients are unavailable in this workspace.") }
        let permitted = records.filter { $0.status == .eligible && $0.smsPermission == "recorded" && !$0.permissionEvidence.isEmpty && !$0.optedOut }
        if records.count != permitted.count { blockers.append("Every selected lead needs eligible status, recorded SMS permission and no opt-out.") }
        campaign.recipientCount = permitted.count
        campaign.needsRecheck = value.status == .readyToConnect && (value.preparedPartnerRevision != partner.revision || value.preparedLeadRevisions != Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.revision) }))
        if campaign.needsRecheck { blockers.append("Workspace or recipients changed since preparation; prepare again.") }
        if value.status == .paused || value.status == .archived { blockers.append("Campaign is \(value.status.title.lowercased()).") }
        campaign.blockers = blockers
        return campaign
    }
    private func campaignValue(partnerID: UUID, id: UUID) throws -> CampaignRecord {
        guard let value = campaignRecords[id], value.partnerID == partnerID else { throw CampaignError.missing }; return value
    }
    private func logCampaign(_ value: inout CampaignRecord, action: String, detail: String) {
        value.revision += 1; value.updatedAt = .now
        campaignActivities[value.id, default: []].append(CampaignActivity(id: UUID(), action: action, detail: detail, actorName: "You (demo)", timestamp: value.updatedAt))
        campaignRecords[value.id] = value
    }
    func campaigns(partnerID: UUID, offset: Int) async throws -> [CampaignRecord] {
        guard partners[partnerID] != nil else { throw CampaignError.missing }
        return try campaignRecords.values.filter { $0.partnerID == partnerID }.sorted { $0.updatedAt > $1.updatedAt }.dropFirst(max(0, offset)).prefix(50).map(campaignSnapshot)
    }
    func campaign(partnerID: UUID, id: UUID) async throws -> CampaignRecord { try campaignSnapshot(campaignValue(partnerID: partnerID, id: id)) }
    func saveCampaign(partnerID: UUID, id: UUID?, config: CampaignConfig, expectedRevision: Int?) async throws -> CampaignRecord {
        guard let partner = partners[partnerID] else { throw CampaignError.missing }
        guard partner.status != .paused else { throw CampaignError.locked }
        let issues = CampaignValidation.draftIssues(config)
        guard issues.isEmpty else { throw CampaignError.invalid(issues.joined(separator: "\n")) }
        var value: CampaignRecord
        if let id {
            value = try campaignValue(partnerID: partnerID, id: id)
            guard expectedRevision == value.revision else { throw CampaignError.conflict }
            guard value.status != .paused && value.status != .archived else { throw CampaignError.locked }
        } else { value = CampaignRecord(id: UUID(), partnerID: partnerID, revision: 0, config: config) }
        value.config = config; value.status = .draft; value.preparedPartnerRevision = nil; value.preparedLeadRevisions = [:]
        logCampaign(&value, action: id == nil ? "created" : "draft_saved", detail: "Draft saved; preparation reset")
        return try campaignSnapshot(value)
    }
    func prepareCampaign(partnerID: UUID, id: UUID, expectedRevision: Int) async throws -> CampaignRecord {
        var value = try campaignValue(partnerID: partnerID, id: id)
        guard value.revision == expectedRevision else { throw CampaignError.conflict }
        guard value.status != .paused && value.status != .archived else { throw CampaignError.locked }
        value.status = .draft
        let snapshot = try campaignSnapshot(value)
        guard snapshot.blockers.isEmpty else { throw CampaignError.invalid(snapshot.blockers.joined(separator: "\n")) }
        value.status = .readyToConnect; value.preparedPartnerRevision = partners[partnerID]!.revision
        value.preparedLeadRevisions = Dictionary(uniqueKeysWithValues: leadRecords[partnerID, default: []].filter { value.config.leadIDs.contains($0.id) }.map { ($0.id, $0.revision) })
        logCampaign(&value, action: "prepared", detail: "Self-service preparation complete. No messages sent.")
        return try campaignSnapshot(value)
    }
    func controlCampaign(partnerID: UUID, id: UUID, action: String, reason: String, expectedRevision: Int) async throws -> CampaignRecord {
        var value = try campaignValue(partnerID: partnerID, id: id)
        guard value.revision == expectedRevision else { throw CampaignError.conflict }
        guard value.status != .archived else { throw CampaignError.locked }
        guard reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5, reason.count <= 2000 else { throw CampaignError.invalid("Explain the status change using 5 to 2,000 characters.") }
        switch action {
        case "pause": value.status = .paused
        case "resume":
            guard value.status == .paused, partners[partnerID]?.status != .paused else { throw CampaignError.locked }; value.status = .draft
        case "archive": value.status = .archived
        default: throw CampaignError.invalid("Unknown campaign action.")
        }
        value.preparedPartnerRevision = nil; value.preparedLeadRevisions = [:]
        logCampaign(&value, action: action, detail: reason)
        return try campaignSnapshot(value)
    }
    func campaignHistory(partnerID: UUID, id: UUID, offset: Int) async throws -> [CampaignActivity] {
        _ = try campaignValue(partnerID: partnerID, id: id)
        return Array(campaignActivities[id, default: []].reversed().dropFirst(max(0, offset)).prefix(50))
    }
    func conversations(partnerID: UUID, campaignID: UUID, offset: Int) async throws -> [ConversationRecord] {
        _ = try campaignValue(partnerID: partnerID, id: campaignID)
        return Array(conversationRecords[campaignID, default: []].sorted { $0.updatedAt > $1.updatedAt }.dropFirst(max(0, offset)).prefix(50))
    }
    func trackConversation(partnerID: UUID, campaignID: UUID, leadID: UUID, note: String) async throws -> ConversationRecord {
        var campaign = try campaignValue(partnerID: partnerID, id: campaignID)
        guard campaign.status != .paused && campaign.status != .archived, partners[partnerID]?.status != .paused else { throw CampaignError.locked }
        guard campaign.config.leadIDs.contains(leadID), leadRecords[partnerID, default: []].contains(where: { $0.id == leadID }) else { throw CampaignError.missing }
        guard note.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5, note.count <= 2000 else { throw CampaignError.invalid("Add an internal tracking note using 5 to 2,000 characters.") }
        guard !conversationRecords[campaignID, default: []].contains(where: { $0.leadID == leadID }) else { throw CampaignError.invalid("This recipient already has a tracking record.") }
        let value = ConversationRecord(id: UUID(), campaignID: campaignID, leadID: leadID)
        conversationRecords[campaignID, default: []].append(value)
        conversationNotes[value.id, default: []].append(ConversationNote(id: UUID(), status: .new, note: note, actorName: "You (demo)", timestamp: .now))
        logCampaign(&campaign, action: "tracking_opened", detail: "Manual tracking opened for recipient \(leadID)")
        return value
    }
    func updateConversation(partnerID: UUID, campaignID: UUID, id: UUID, status: ConversationStatus, note: String, expectedRevision: Int) async throws -> ConversationRecord {
        var campaign = try campaignValue(partnerID: partnerID, id: campaignID)
        guard campaign.status != .paused && campaign.status != .archived, partners[partnerID]?.status != .paused else { throw CampaignError.locked }
        guard let index = conversationRecords[campaignID]?.firstIndex(where: { $0.id == id }) else { throw CampaignError.missing }
        var value = conversationRecords[campaignID]![index]
        guard value.revision == expectedRevision else { throw CampaignError.conflict }
        guard note.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5, note.count <= 2000 else { throw CampaignError.invalid("Add an internal tracking note using 5 to 2,000 characters.") }
        value.status = status; value.revision += 1; value.updatedAt = .now; conversationRecords[campaignID]![index] = value
        conversationNotes[id, default: []].append(ConversationNote(id: UUID(), status: status, note: note, actorName: "You (demo)", timestamp: .now))
        logCampaign(&campaign, action: "tracking_updated", detail: "Manual tracking updated to \(status.title)")
        return value
    }
    func conversationHistory(partnerID: UUID, campaignID: UUID, id: UUID, offset: Int) async throws -> [ConversationNote] {
        _ = try campaignValue(partnerID: partnerID, id: campaignID)
        guard conversationRecords[campaignID, default: []].contains(where: { $0.id == id }) else { throw CampaignError.missing }
        return Array(conversationNotes[id, default: []].reversed().dropFirst(max(0, offset)).prefix(50))
    }
}
