import Foundation
import Observation

@MainActor @Observable
final class DemoMessagesSentViewModel {
    let contacts = DemoCampaignMessageFixtures.contacts
    let campaign: DemoOnlineCampaign
    init(campaign: DemoOnlineCampaign) { self.campaign = campaign }
    func thread(for contact: DemoContactedLead) -> DemoMessageThreadViewModel {
        DemoMessageThreadViewModel(contact: contact, campaignTitle: campaign.title)
    }
}
