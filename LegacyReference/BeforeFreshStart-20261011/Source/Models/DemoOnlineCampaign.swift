import Foundation

/// A fictional online campaign preview. Never serialized to the live API.
struct DemoOnlineCampaign: Sendable {
    let title: String
    let offer: String
    let aiName: String
    let goal: String
    let handoffEmail: String
    let recipients: Int
    let messagesSent: Int
    let replies: Int
    let salesHandoffs: Int
    let conversions: Int
    let revenue: Double

    static let sample = DemoOnlineCampaign(
        title: "Spring roofing recovery",
        offer: "Free roof inspection and 10% off a qualifying repair",
        aiName: "Emma",
        goal: "Reconnect with homeowners who previously requested a quote. Find out whether they still need help, explain the inspection offer, and hand interested homeowners to the sales team.",
        handoffEmail: "sales@example.com",
        recipients: 500, messagesSent: 320, replies: 64,
        salesHandoffs: 40, conversions: 18, revenue: 12600
    )
}
