import Foundation
import Observation

@MainActor @Observable
final class ConversationViewModel {
    private(set) var record: ConversationRecord
    private(set) var notes: [ConversationNote] = []
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private(set) var more = false
    var status: ConversationStatus
    var note = ""
    @ObservationIgnored private let partnerID: UUID
    @ObservationIgnored private let repository: any CampaignRepository
    init(partnerID: UUID, record: ConversationRecord, repository: any CampaignRepository) { self.partnerID = partnerID; self.record = record; self.repository = repository; status = record.status }
    func load(more: Bool = false) async {
        guard !isBusy else { return }; isBusy = true; errorMessage = nil; defer { isBusy = false }
        do {
            if !more {
                var offset = 0
                while true {
                    let page = try await repository.conversations(partnerID: partnerID, campaignID: record.campaignID, offset: offset)
                    if let current = page.first(where: { $0.id == record.id }) { record = current; status = current.status; break }
                    if page.count < 50 { throw CampaignError.missing }; offset += page.count
                }
            }
            let page = try await repository.conversationHistory(partnerID: partnerID, campaignID: record.campaignID, id: record.id, offset: more ? notes.count : 0)
            notes = more ? notes + page : page; self.more = page.count == 50
        } catch { errorMessage = error.localizedDescription }
    }
    func save() async {
        guard !isBusy else { return }; isBusy = true; errorMessage = nil
        do { record = try await repository.updateConversation(partnerID: partnerID, campaignID: record.campaignID, id: record.id, status: status, note: note, expectedRevision: record.revision); note = "" } catch { errorMessage = error.localizedDescription }
        isBusy = false
        if errorMessage == nil { await load() }
    }
}
