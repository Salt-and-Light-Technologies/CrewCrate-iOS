import Foundation
import Observation

@MainActor
@Observable
final class RecipientReviewViewModel {
    var campaign: CampaignSummary
    var leads: [CampaignLead] = []
    var batches: [LeadBatch] = []
    var selected: Set<UUID> = []
    var search = ""
    var filter = "all"
    var listID = "campaign"
    var reviewingLead: CampaignLead?
    var isBusy = false
    var hasLoaded = false
    var hasMore = false
    private var nextOffset = 0
    var notice: String?
    let service: any CampaignServicing
    init(campaign: CampaignSummary, service: any CampaignServicing) {
        self.campaign = campaign; self.service = service
    }
    var visible: [CampaignLead] {
        leads.filter { lead in
            let listMatches = listID == "all" || (listID == "campaign" && campaign.config.leadIDs.contains(lead.id)) || lead.import_id.uuidString == listID
            let statusMatches = filter == "all" || (filter == "eligible" && lead.eligible_for_sms) || (filter == "excluded" && !lead.eligible_for_sms)
            let term = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return listMatches && statusMatches && (term.isEmpty || [lead.name, lead.phone, lead.email].contains { $0.lowercased().contains(term) })
        }
    }
    var canSave: Bool { hasLoaded && !isBusy && campaign.ownerHold != true && !["paused", "archived"].contains(campaign.status) }
    func load() async {
        guard !isBusy else { return }
        isBusy = true; notice = nil
        leads = []; hasMore = false; nextOffset = 0
        defer { isBusy = false }
        do {
            let current = try await service.campaign(partnerID: campaign.partnerID, campaignID: campaign.id)
            let contacts = try await fetchPage(offset: 0)
            let imports = try await service.leadBatches(partnerID: campaign.partnerID)
            campaign = current; leads = contacts; batches = imports
            if !hasLoaded { selected = Set(current.config.leadIDs) }
            for contact in contacts where !contact.eligible_for_sms { selected.remove(contact.id) }
            nextOffset = contacts.count; hasMore = contacts.count == 250
            hasLoaded = true
        } catch { notice = error.localizedDescription }
    }
    private func fetchPage(offset: Int) async throws -> [CampaignLead] {
        try await service.campaignLeads(partnerID: campaign.partnerID,
            campaignID: listID == "campaign" ? campaign.id : nil,
            importID: UUID(uuidString: listID), eligibility: filter,
            search: String(search.prefix(200)), offset: offset)
    }
    func loadMore() async {
        guard !isBusy && hasMore else { return }
        isBusy = true; notice = nil
        defer { isBusy = false }
        do {
            let page = try await fetchPage(offset: nextOffset)
            let existingIDs = Set(leads.map(\.id))
            leads += page.filter { !existingIDs.contains($0.id) }
            for contact in page where !contact.eligible_for_sms { selected.remove(contact.id) }
            nextOffset += page.count; hasMore = page.count == 250
        } catch { notice = error.localizedDescription }
    }
    func toggle(_ lead: CampaignLead) {
        guard lead.eligible_for_sms && !isBusy else { return }
        if selected.contains(lead.id) { selected.remove(lead.id) }
        else if selected.count < 10000 { selected.insert(lead.id) }
        else { notice = "A campaign supports up to 10,000 recipients." }
    }
    func selectVisible() {
        let eligible = visible.filter(\.eligible_for_sms).map(\.id)
        let available = 10000 - selected.count
        let additions = eligible.filter { !selected.contains($0) }
        selected.formUnion(additions.prefix(available))
        if additions.count > available { notice = "Selected up to the 10,000-recipient campaign limit." }
    }
    func selectAllEligible() async {
        guard !isBusy && hasLoaded else { return }
        isBusy = true; notice = nil
        defer { isBusy = false }
        do {
            let ids = try await service.eligibleLeadIDs(partnerID: campaign.partnerID,
                campaignID: listID == "campaign" ? campaign.id : nil,
                importID: UUID(uuidString: listID), search: String(search.prefix(200)))
            selected = Set(ids)
            filter = "eligible"
            leads = []
            let page = try await fetchPage(offset: 0)
            leads = page; nextOffset = page.count; hasMore = page.count == 250
            notice = "Selected all \(ids.count) eligible leads matching this list and search. Save eligible recipients to apply."
        } catch { notice = error.localizedDescription }
    }
    func reviewed(_ lead: CampaignLead) {
        if let index = leads.firstIndex(where: { $0.id == lead.id }) { leads[index] = lead }
        if !lead.eligible_for_sms { selected.remove(lead.id) }
    }
    func saveSelection() async -> CampaignSummary? {
        guard canSave else { return nil }
        isBusy = true; notice = nil
        defer { isBusy = false }
        do {
            let result = try await service.selectRecipients(partnerID: campaign.partnerID, campaignID: campaign.id,
                revision: campaign.revision, leadIDs: selected.sorted { $0.uuidString < $1.uuidString })
            campaign = result.campaign; selected = Set(campaign.config.leadIDs)
            if result.removed_count > 0 { notice = "Removed \(result.removed_count) contacts that no longer pass permission checks." }
            return campaign
        } catch { notice = error.localizedDescription; return nil }
    }
}

@MainActor
@Observable
final class LeadPermissionViewModel {
    let lead: CampaignLead
    let partnerID: UUID
    let service: any OutreachServicing
    var showsPermissionEditor = false
    var statusTitle: String {
        if lead.opted_out || lead.sms_permission == "revoked" { return "Do not text — opted out" }
        if lead.eligible_for_sms { return "Eligible for texts" }
        if lead.status == "excluded" { return "Excluded from texts" }
        return "Not eligible — permission needed"
    }
    var statusExplanation: String {
        if lead.opted_out || lead.sms_permission == "revoked" { return "This contact asked to stop texts and cannot be re-enabled here." }
        if lead.eligible_for_sms { return "SMS permission is recorded. This contact can be selected for campaign outreach." }
        if lead.status == "excluded" { return "This contact has been excluded from campaign outreach." }
        return "Record their permission before selecting this contact. Importing a lead does not grant permission."
    }
    var action = "record_permission"
    var evidence = ""
    var source = ""
    var consentDate = ""
    var country = ""
    var attested = false
    var isBusy = false
    var error: String?
    init(lead: CampaignLead, partnerID: UUID, service: any OutreachServicing) {
        self.lead = lead; self.partnerID = partnerID; self.service = service
        if lead.opted_out || lead.sms_permission == "revoked" { action = "exclude" }
    }
    var canSave: Bool {
        !isBusy && evidence.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8 &&
        (action != "record_permission" || (attested && !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && country.count == 2 && consentDate.count == 10 && !lead.opted_out && lead.sms_permission != "revoked"))
    }
    func save() async -> CampaignLead? {
        guard canSave else { return nil }
        isBusy = true; error = nil
        defer { isBusy = false }
        do {
            return try await service.reviewLead(partnerID: partnerID, leadID: lead.id, review: LeadReview(
                expected_revision: lead.revision, action: action, evidence: evidence,
                source: source, consent_date: consentDate, country: country.uppercased(), attested: attested))
        } catch { self.error = error.localizedDescription; return nil }
    }
}
