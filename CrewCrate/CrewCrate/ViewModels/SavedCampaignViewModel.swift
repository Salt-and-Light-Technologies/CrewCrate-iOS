import Foundation
import Observation

@MainActor
@Observable
final class SavedCampaignViewModel {
    var campaign: CampaignSummary
    var showsEditor = false
    var showsTest = false
    var isLoading = false
    var error: String?
    let service: any CampaignServicing
    init(campaign: CampaignSummary, service: any CampaignServicing) {
        self.campaign = campaign; self.service = service
    }
    var canEdit: Bool { !isLoading && !["paused", "archived"].contains(campaign.status) }
    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil
        defer { isLoading = false }
        do { campaign = try await service.campaign(partnerID: campaign.partnerID, campaignID: campaign.id) }
        catch { self.error = error.localizedDescription }
    }
    func didSave(_ updated: CampaignSummary) { campaign = updated; error = nil }
}
