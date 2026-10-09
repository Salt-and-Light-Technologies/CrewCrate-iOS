import Foundation

/// Illustrative performance only. These records do not claim live messaging or sales evidence.
nonisolated struct OwnerPartnerAnalytics: Identifiable, Sendable {
    let id: UUID
    let totalLeads: Int
    let messaged: Int
    let replied: Int
    let qualified: Int
    let salesTouched: Int
    let qualifiedAwaitingSales: Int
    let appointments: Int
    let converted: Int
    let overdueFollowUps: Int
    let salesWithRecords: Int
    let reportedRevenue: Decimal
    var notMessaged: Int { max(0, totalLeads - messaged) }
    var salesMissingRecords: Int { max(0, converted - salesWithRecords) }
    var messagingRate: Double { totalLeads > 0 ? Double(messaged) / Double(totalLeads) : 0 }
    var conversionRate: Double { totalLeads > 0 ? Double(converted) / Double(totalLeads) : 0 }
    var replyRate: Double { messaged > 0 ? Double(replied) / Double(messaged) : 0 }
}
