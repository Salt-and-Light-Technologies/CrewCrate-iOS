import Foundation
import Observation

@MainActor @Observable
final class ConversationListViewModel {
    private(set) var records: [ConversationRecord] = []
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private(set) var more = false
    var selectedLead: UUID?
    var note = ""
    let recipients: [LeadRecord]
    let isDemo: Bool
    @ObservationIgnored private let partnerID: UUID
    @ObservationIgnored private let campaign: CampaignRecord
    @ObservationIgnored private let repository: any CampaignRepository
    init(partnerID: UUID, campaign: CampaignRecord, repository: any CampaignRepository, candidates: [LeadRecord], isDemo: Bool) { self.partnerID = partnerID; self.campaign = campaign; self.repository = repository; recipients = candidates.filter { campaign.config.leadIDs.contains($0.id) }; self.isDemo = isDemo }
    func load(more: Bool = false) async {
        guard !isBusy else { return }; isBusy = true; errorMessage = nil; defer { isBusy = false }
        do { let page = try await repository.conversations(partnerID: partnerID, campaignID: campaign.id, offset: more ? records.count : 0); records = more ? records + page : page; self.more = page.count == 50 } catch { errorMessage = error.localizedDescription }
    }
    func create() async {
        guard !isBusy, let selectedLead else { errorMessage = "Choose a recipient."; return }
        isBusy = true; errorMessage = nil
        do { _ = try await repository.trackConversation(partnerID: partnerID, campaignID: campaign.id, leadID: selectedLead, note: note); note = ""; self.selectedLead = nil }
        catch { errorMessage = error.localizedDescription }
        isBusy = false
        if errorMessage == nil { await load() }
    }
    func recipientName(_ id: UUID) -> String { recipients.first(where: { $0.id == id })?.name ?? id.uuidString }
    func detail(_ value: ConversationRecord) -> ConversationViewModel { ConversationViewModel(partnerID: partnerID, record: value, repository: repository) }
}
