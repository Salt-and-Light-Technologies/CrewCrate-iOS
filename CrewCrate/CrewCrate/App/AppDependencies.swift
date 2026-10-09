import Foundation

/// The only live composition point: selects adapters and constructs feature view-models.
@MainActor
struct AppDependencies {
    static func makeSession() -> SessionViewModel {
        let auth = SupabaseSession()
        return SessionViewModel(auth: auth, loadIdentity: {
            let api = try APILeadRepository(baseURL: LiveConfiguration.apiURL, tokens: auth, ownerWorkspace: false)
            return try await api.identity()
        }, makeExperience: { identity in
            let api = try APILeadRepository(baseURL: LiveConfiguration.apiURL, tokens: auth, ownerWorkspace: identity.is_owner)
            return PartnerExperienceViewModel(repository: api, analytics: PartnerHomeViewModel(repository: CampaignAnalyticsService(campaigns: api), demoRepository: DemoCampaignAnalyticsRepository()), isOwner: identity.is_owner,
                makeHandoffDirectory: { partner in SalesHandoffViewModel(partnerID: partner.id, partnerName: partner.name, repository: api) },
                makeContactWorkspace: { partner in LeadWorkspaceViewModel(id: partner.id, repository: api, isDemo: false) },
                makeCampaigns: { partner in CampaignListViewModel(partnerID: partner.id, name: partner.name, repository: api, leads: api, isDemo: false) },
                makeOnboarding: { partner, completion in
                    OnboardingViewModel(store: LiveOnboardingStore(api: api, partnerID: partner.id), isLive: true, onSubmitted: completion, inspector: LeadFileInspector())
                })
        })
    }
}
