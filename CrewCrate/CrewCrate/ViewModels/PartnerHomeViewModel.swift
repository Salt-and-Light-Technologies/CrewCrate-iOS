import Foundation
import Observation

@MainActor @Observable
final class PartnerHomeViewModel {
    private(set) var snapshots: [CampaignSnapshot] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var hasLoaded = false
    var campaignFilter: UUID?
    var statusFilter: CampaignStatus?
    @ObservationIgnored private let repository: any CampaignAnalyticsRepository
    var showsDemo: Bool
    @ObservationIgnored private let demoRepository: (any CampaignAnalyticsRepository)?
    init(repository: any CampaignAnalyticsRepository, demoRepository: (any CampaignAnalyticsRepository)? = nil) { self.repository = repository; self.demoRepository = demoRepository; showsDemo = demoRepository != nil }
    var filtered: [CampaignSnapshot] {
        snapshots.filter { (campaignFilter == nil || $0.id == campaignFilter) && (statusFilter == nil || $0.campaign.status == statusFilter) }
    }
    var sent: Int { filtered.reduce(0) { $0 + ($1.demoMetrics?.sent ?? 0) } }
    var replies: Int { filtered.reduce(0) { $0 + ($1.demoMetrics?.replies ?? 0) } }
    var conversions: Int { filtered.reduce(0) { $0 + ($1.demoMetrics?.conversions ?? 0) } }
    var revenue: Double { filtered.reduce(0) { $0 + ($1.demoMetrics?.revenue ?? 0) } }
    var recipients: Int { filtered.reduce(0) { $0 + $1.recipients } }
    var touches: Int { filtered.reduce(0) { $0 + $1.salesTouches } }
    var appointments: Int { filtered.reduce(0) { $0 + $1.recorded(.appointment) } }
    func load() async {
        guard !isLoading else { return }; isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await (showsDemo ? (demoRepository ?? repository) : repository).snapshots()
            snapshots = result.sorted { $0.campaign.updatedAt > $1.campaign.updatedAt }; hasLoaded = true
            if let selected = campaignFilter, !snapshots.contains(where: { $0.id == selected }) { campaignFilter = nil }
        } catch { errorMessage = error.localizedDescription }
    }
}
