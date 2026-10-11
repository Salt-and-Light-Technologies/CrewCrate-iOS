import Foundation

struct DemoCampaignMessage: Identifiable, Sendable {
    let id: Int
    let text: String
    let time: String
    let isOutbound: Bool
}

struct DemoContactedLead: Identifiable, Sendable {
    let id: Int
    let name: String
    let phone: String
    let outcome: String
    let messages: [DemoCampaignMessage]
}
