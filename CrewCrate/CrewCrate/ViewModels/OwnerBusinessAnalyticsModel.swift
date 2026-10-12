import Foundation
import Observation

@MainActor
@Observable
final class OwnerBusinessAnalyticsModel {
    var analytics: OwnerBusinessAnalytics?
    var campaigns: [WorkspaceCampaign] = []
    var isLoading = false
    var analyticsError: String?
    var campaignsError: String?
    let business: BusinessSummary
    private let analyticsService: any OwnerAnalyticsServicing
    private let campaignService: any CampaignWorkspaceServicing
    init(business: BusinessSummary, analyticsService: any OwnerAnalyticsServicing,
         campaignService: any CampaignWorkspaceServicing) {
        self.business = business; self.analyticsService = analyticsService; self.campaignService = campaignService
    }
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        async let summary = analyticsService.ownerAnalytics(business: business.id)
        async let plans = campaignService.campaigns(business: business.id)
        do { analytics = try await summary; analyticsError = nil }
        catch { analyticsError = error.localizedDescription }
        do { campaigns = try await plans; campaignsError = nil }
        catch { campaignsError = error.localizedDescription }
    }
}
