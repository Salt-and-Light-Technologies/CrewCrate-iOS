import Foundation
import Observation

@MainActor
@Observable
final class AITestViewModel {
    var conversation: AITestConversation?
    var message = ""
    var isBusy = false
    var error: String?
    private let service: any TestAIServicing
    private let partnerID: UUID
    private let campaignID: UUID?
    private let config: CampaignDetails?
    private var pending: (id: UUID, text: String, revision: Int)?
    init(service: any TestAIServicing, partnerID: UUID, campaignID: UUID? = nil, config: CampaignDetails? = nil) {
        self.service = service; self.partnerID = partnerID; self.campaignID = campaignID; self.config = config
    }
    var canSend: Bool { conversation?.isActive == true && !isBusy && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && message.count <= 2000 }
    func start() async {
        guard !isBusy else { return }
        isBusy = true; error = nil
        defer { isBusy = false }
        do {
            let value = try await service.startAITest(partnerID: partnerID, campaignID: campaignID, config: config)
            conversation = value; pending = nil; message = ""
        } catch { self.error = error.localizedDescription }
    }
    func send() async {
        guard canSend, let conversation else { return }
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if let pending, pending.text != text {
            error = "Retry your previous message or refresh the conversation before sending a different one."
            return
        }
        let attempt = pending ?? (UUID(), text, conversation.revision)
        pending = attempt
        isBusy = true; error = nil
        defer { isBusy = false }
        do {
            self.conversation = try await service.sendAITest(partnerID: partnerID, testID: conversation.id, revision: attempt.revision, requestID: attempt.id, text: attempt.text)
            message = ""; pending = nil
        } catch { self.error = error.localizedDescription }
    }
    func refresh() async {
        guard !isBusy, let conversation else { return }
        isBusy = true; error = nil
        defer { isBusy = false }
        do {
            self.conversation = try await service.aiTest(partnerID: partnerID, testID: conversation.id)
            if self.conversation?.revision != conversation.revision { pending = nil; message = "" }
        } catch { self.error = error.localizedDescription }
    }
}
