import Foundation
import Observation

@MainActor @Observable
final class DemoOnlineCampaignViewModel {
    let campaign: DemoOnlineCampaign
    init(campaign: DemoOnlineCampaign = .sample) { self.campaign = campaign }
    func messagesSent() -> DemoMessagesSentViewModel { DemoMessagesSentViewModel(campaign: campaign) }
    var contactProgress: Double { Double(campaign.messagesSent) / Double(max(campaign.recipients, 1)) }
    var replyRate: Double { Double(campaign.replies) / Double(max(campaign.messagesSent, 1)) }
}
