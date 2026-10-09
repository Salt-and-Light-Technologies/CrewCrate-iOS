import Foundation
import Observation

@MainActor @Observable
final class PartnerExperienceViewModel {
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    private(set) var onboarding: OnboardingViewModel?
    private(set) var handoffDirectories: [SalesHandoffViewModel] = []
    @ObservationIgnored private let makeHandoffDirectory: (@MainActor (LivePartner) -> SalesHandoffViewModel)?
    private(set) var contactWorkspaces: [LeadWorkspaceViewModel] = []
    @ObservationIgnored private let makeContactWorkspace: (@MainActor (LivePartner) -> LeadWorkspaceViewModel)?
    private(set) var campaigns: [CampaignListViewModel] = []
    @ObservationIgnored private let makeCampaigns: (@MainActor (LivePartner) -> CampaignListViewModel)?
    let analytics: PartnerHomeViewModel
    @ObservationIgnored private let repository: any PartnerSetupRepository
    @ObservationIgnored private let isOwner: Bool
    @ObservationIgnored private let makeOnboarding: @MainActor (LivePartner, @escaping OnboardingCompletion) -> OnboardingViewModel

    init(repository: any PartnerSetupRepository, analytics: PartnerHomeViewModel, isOwner: Bool,
         makeHandoffDirectory: (@MainActor (LivePartner) -> SalesHandoffViewModel)? = nil,
         makeContactWorkspace: (@MainActor (LivePartner) -> LeadWorkspaceViewModel)? = nil,
         makeCampaigns: (@MainActor (LivePartner) -> CampaignListViewModel)? = nil,
         makeOnboarding: @escaping @MainActor (LivePartner, @escaping OnboardingCompletion) -> OnboardingViewModel) {
        self.makeHandoffDirectory = makeHandoffDirectory
        self.makeContactWorkspace = makeContactWorkspace
        self.makeCampaigns = makeCampaigns
        self.repository = repository
        self.isOwner = isOwner
        self.analytics = analytics
        self.makeOnboarding = makeOnboarding
    }
    func load() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let partners = try await repository.setupPartners()
            handoffDirectories = partners.compactMap { makeHandoffDirectory?($0) }
            contactWorkspaces = partners.compactMap { makeContactWorkspace?($0) }
            campaigns = partners.compactMap { makeCampaigns?($0) }
            if !isOwner && partners.isEmpty { throw LeadAPIError.server("Your account is connected. Your administrator needs to assign your business workspace before onboarding can begin.") }
            if !isOwner, let pending = partners.first(where: { Self.requiresOnboarding($0.status) }) {
                onboarding = makeOnboarding(pending) { [weak self] in await self?.load() }
            } else { onboarding = nil }
        } catch { errorMessage = error.localizedDescription }
    }
    nonisolated static func requiresOnboarding(_ status: String) -> Bool { status == "draft" || status == "changes_requested" }
}
