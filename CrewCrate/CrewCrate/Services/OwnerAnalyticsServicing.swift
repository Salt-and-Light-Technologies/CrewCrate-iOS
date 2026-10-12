import Foundation

nonisolated protocol OwnerAnalyticsServicing: Sendable {
    func ownerAnalytics(business: UUID) async throws -> OwnerBusinessAnalytics
}
extension SupabaseSession: OwnerAnalyticsServicing {
    func ownerAnalytics(business: UUID) async throws -> OwnerBusinessAnalytics {
        try await apiRequest("v1/owner/partners/\(business)/analytics")
    }
}
