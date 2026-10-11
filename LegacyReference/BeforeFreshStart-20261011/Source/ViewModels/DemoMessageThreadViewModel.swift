import Foundation
import Observation

@MainActor @Observable
final class DemoMessageThreadViewModel {
    let contact: DemoContactedLead
    let campaignTitle: String
    init(contact: DemoContactedLead, campaignTitle: String) {
        self.contact = contact; self.campaignTitle = campaignTitle
    }
}
