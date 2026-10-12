import Foundation

nonisolated struct OwnerBusinessAnalytics: Decodable, Sendable {
    let partner_id: UUID
    let name: String
    let access_approved: Bool
    let total_contacts: Int
    let import_count: Int
    let campaign_count: Int
    let campaign_status_counts: [String: Int]
    let lead_status_counts: [String: Int]
    let manual_conversation_count: Int
    let manual_status_counts: [String: Int]
    let sms_connected: Bool
}
