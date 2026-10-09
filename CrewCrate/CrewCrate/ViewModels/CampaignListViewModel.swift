import Foundation
import Observation

@MainActor @Observable
final class CampaignListViewModel {
    let onlineDemo = DemoOnlineCampaign.sample
    let name: String
    private(set) var records: [CampaignRecord] = []
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private(set) var hasMore = false
    let isDemo: Bool
    @ObservationIgnored private let partnerID: UUID
    @ObservationIgnored private let repository: any CampaignRepository
    @ObservationIgnored private let leads: any LeadRepository
    init(partnerID: UUID, name: String, repository: any CampaignRepository, leads: any LeadRepository, isDemo: Bool) { self.partnerID = partnerID; self.name = name; self.repository = repository; self.leads = leads; self.isDemo = isDemo }
    func load(more: Bool = false) async {
        guard !isBusy else { return }; isBusy = true; errorMessage = nil; defer { isBusy = false }
        do { let page = try await repository.campaigns(partnerID: partnerID, offset: more ? records.count : 0); records = more ? records + page : page; hasMore = page.count == 50 } catch { errorMessage = error.localizedDescription }
    }
    func editor(id: UUID? = nil) -> CampaignEditorViewModel { CampaignEditorViewModel(partnerID: partnerID, id: id, repository: repository, leads: leads, isDemo: isDemo) }
}
