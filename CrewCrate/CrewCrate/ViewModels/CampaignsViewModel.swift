import Foundation
import Observation

@MainActor
@Observable
final class CampaignsViewModel {
    var workspaces: [CampaignWorkspace] = []
    var campaigns: [CampaignSummary] = []
    var isLoading = false
    var hasLoaded = false
    var error: String?
    var showsDetails = false
    let service: any CampaignServicing
    init(service: any CampaignServicing) { self.service = service }
    func replace(_ campaign: CampaignSummary) {
        if let index = campaigns.firstIndex(where: { $0.id == campaign.id }) { campaigns[index] = campaign }
    }
    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            let spaces = try await service.workspaces()
            var results: [CampaignSummary] = []
            for space in spaces { results += try await service.campaigns(partnerID: space.id) }
            workspaces = spaces; campaigns = results; hasLoaded = true
        } catch { self.error = error.localizedDescription }
    }
}
