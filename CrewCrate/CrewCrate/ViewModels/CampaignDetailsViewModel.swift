import Foundation
import Observation

@MainActor
@Observable
final class CampaignDetailsViewModel {
    var details = CampaignDetails()
    var showsAITest = false
    var workspaceID: UUID?
    var isSaving = false
    var notice: String?
    let service: any CampaignServicing
    let workspaces: [CampaignWorkspace]
    init(service: any CampaignServicing, workspaces: [CampaignWorkspace]) {
        self.service = service; self.workspaces = workspaces
        workspaceID = workspaces.first(where: { $0.status != "paused" })?.id
    }
    var hasEdits: Bool {
        !details.name.isEmpty || !details.offer.isEmpty || !(details.aiName ?? "").isEmpty || !(details.aiBrief ?? "").isEmpty || !details.qualification.isEmpty || !details.handoffEmail.isEmpty
    }
    var canSave: Bool { !isSaving && workspaceID != nil && !details.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func save() async -> Bool {
        guard canSave, let workspaceID else { return false }
        isSaving = true; defer { isSaving = false }
        do {
            details.name = details.name.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try await service.createCampaign(partnerID: workspaceID, details: details)
            return true
        } catch { notice = error.localizedDescription; return false }
    }
}
