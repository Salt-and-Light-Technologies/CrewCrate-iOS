import Foundation
import Observation

@MainActor @Observable
final class OwnerDashboardViewModel {
    private(set) var partners: [PartnerWorkspace] = []
    private(set) var performance: [OwnerPartnerAnalytics] = []
    private(set) var analyticsError: String?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var search = ""
    var statusFilter: PartnerStatus?
    @ObservationIgnored private let repository: any PartnerRepository
    @ObservationIgnored private let leadRepository: (any LeadRepository)?
    @ObservationIgnored private let analyticsProvider: (any OwnerAnalyticsProvider)?
    init(repository: any PartnerRepository, leadRepository: (any LeadRepository)? = nil, analyticsProvider: (any OwnerAnalyticsProvider)? = nil) { self.repository = repository; self.leadRepository = leadRepository; self.analyticsProvider = analyticsProvider }
    func makeLeadViewModel(id: UUID) -> LeadWorkspaceViewModel? {
        guard let leadRepository else { return nil }
        return LeadWorkspaceViewModel(id: id, repository: leadRepository)
    }
    var filteredPartners: [PartnerWorkspace] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return partners.filter {
            (statusFilter == nil || $0.status == statusFilter) &&
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.onboarding.industry.localizedCaseInsensitiveContains(query))
        }
    }
    var totalLeadCount: Int { performance.reduce(0) { $0 + $1.totalLeads } }
    var totalMessagedCount: Int { performance.reduce(0) { $0 + $1.messaged } }
    var totalConvertedCount: Int { performance.reduce(0) { $0 + $1.converted } }
    var totalAwaitingSalesCount: Int { performance.reduce(0) { $0 + $1.qualifiedAwaitingSales } }
    var totalReportedRevenue: Decimal { performance.reduce(Decimal.zero) { $0 + $1.reportedRevenue } }
    func partnerName(for metric: OwnerPartnerAnalytics) -> String { partners.first { $0.id == metric.id }?.name.replacingOccurrences(of: " · Sample", with: "") ?? "Sample partner" }
    var awaitingReviewCount: Int { partners.filter { $0.status == .submitted }.count }
    var approvedCount: Int { partners.filter { $0.status == .pilotApproved }.count }
    var pausedCount: Int { partners.filter { $0.status == .paused }.count }
    func load() async {
        guard !isLoading else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { partners = try await repository.list() }
        catch { errorMessage = "Couldn’t refresh partners. \(error.localizedDescription)" }
        if let analyticsProvider {
            analyticsError = nil
            do { performance = try await analyticsProvider.performance() }
            catch { analyticsError = "Couldn’t refresh performance. \(error.localizedDescription)" }
        }
    }
    func makeReviewViewModel(id: UUID) -> PartnerReviewViewModel {
        PartnerReviewViewModel(id: id, repository: repository)
    }
}
