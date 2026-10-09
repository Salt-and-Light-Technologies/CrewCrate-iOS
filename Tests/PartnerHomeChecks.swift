import Foundation
@main struct PartnerHomeChecks {
    @MainActor static func main() async throws {
        assert(PartnerExperienceViewModel.requiresOnboarding("draft"))
        assert(PartnerExperienceViewModel.requiresOnboarding("changes_requested"))
        assert(!PartnerExperienceViewModel.requiresOnboarding("submitted"))
        assert(!PartnerExperienceViewModel.requiresOnboarding("pilot_approved"))
        let partnerID = UUID(), leadA = UUID(), leadB = UUID()
        let record = CampaignRecord(id: UUID(), partnerID: partnerID, config: CampaignConfig(name: "Recovery", leadIDs: [leadA, leadB]))
        let row = CampaignSnapshot(campaign: record, partnerName: "Demo", conversations: [
            ConversationRecord(id: UUID(), campaignID: record.id, leadID: leadA, status: .appointment),
            ConversationRecord(id: UUID(), campaignID: record.id, leadID: leadA, status: .appointment),
            ConversationRecord(id: UUID(), campaignID: record.id, leadID: leadB, status: .interested)
        ])
        assert(row.recipients == 2 && row.salesTouches == 2)
        assert(row.recorded(.appointment) == 1 && row.recorded(.interested) == 1)
        assert(row.recorded(.closed) == 0)
        let demo = DemoPartnerRepository(campaignDemo: true)
        let model = PartnerHomeViewModel(repository: CampaignAnalyticsService(campaigns: demo))
        await model.load()
        assert(model.hasLoaded && model.errorMessage == nil && model.snapshots.isEmpty)
        let workspace = try await demo.workspaces().first!
        let first = try await demo.saveCampaign(partnerID: workspace.id, id: nil, config: CampaignConfig(name: "First"), expectedRevision: nil)
        _ = try await demo.saveCampaign(partnerID: workspace.id, id: nil, config: CampaignConfig(name: "Second"), expectedRevision: nil)
        await model.load()
        assert(model.filtered.count == 2)
        model.campaignFilter = first.id
        assert(model.filtered.count == 1 && model.filtered[0].campaign.config.name == "First")
        model.statusFilter = .paused
        assert(model.filtered.isEmpty)
        model.campaignFilter = nil; model.statusFilter = .draft
        assert(model.filtered.count == 2)
        let preview = PartnerHomeViewModel(repository: CampaignAnalyticsService(campaigns: demo), demoRepository: DemoCampaignAnalyticsRepository())
        await preview.load()
        assert(preview.showsDemo && preview.filtered.count == 4)
        assert(preview.recipients == 2450 && preview.sent == 1780 && preview.replies == 546)
        assert(preview.conversions == 99 && preview.revenue == 56400)
        preview.statusFilter = .paused
        assert(preview.filtered.count == 1 && preview.sent == 420)
        preview.statusFilter = nil
        preview.campaignFilter = preview.snapshots.first!.id
        assert(preview.filtered.count == 1 && preview.recipients == 1200)
        preview.showsDemo = false
        await preview.load()
        assert(preview.snapshots.count == 2 && preview.snapshots.allSatisfy { $0.demoMetrics == nil })
        print("Partner home checks passed: onboarding routing, unique manual touchpoints, campaign/status filters and empty state")
    }
}
