import Foundation
import Observation

@MainActor @Observable
final class CampaignWorkspacesViewModel {
    private(set) var workspaces: [LeadWorkspaceSummary] = []
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    let isDemo: Bool
    @ObservationIgnored private let repository: any CampaignRepository
    @ObservationIgnored private let leads: any LeadRepository
    init(repository: any CampaignRepository, leads: any LeadRepository, isDemo: Bool = true) { self.repository = repository; self.leads = leads; self.isDemo = isDemo }
    func load() async {
        guard !isBusy else { return }; isBusy = true; errorMessage = nil; defer { isBusy = false }
        do { workspaces = try await repository.workspaces() } catch { errorMessage = error.localizedDescription }
    }
    func list(_ workspace: LeadWorkspaceSummary) -> CampaignListViewModel { CampaignListViewModel(partnerID: workspace.id, name: workspace.name, repository: repository, leads: leads, isDemo: isDemo) }
}
