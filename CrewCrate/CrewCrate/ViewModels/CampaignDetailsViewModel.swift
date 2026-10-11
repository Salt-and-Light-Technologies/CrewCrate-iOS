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
    var savedCampaign: CampaignSummary?
    private var existing: CampaignSummary?
    private var original: CampaignDetails
    var isEditing: Bool { existing != nil }
    let service: any CampaignServicing
    let workspaces: [CampaignWorkspace]
    init(service: any CampaignServicing, workspaces: [CampaignWorkspace]) {
        self.service = service; self.workspaces = workspaces
        existing = nil; original = CampaignDetails()
        workspaceID = workspaces.first(where: { $0.status != "paused" })?.id
    }
    init(service: any CampaignServicing, campaign: CampaignSummary) {
        self.service = service; workspaces = []
        existing = campaign; original = campaign.config
        details = campaign.config; workspaceID = campaign.partnerID
    }
    var hasEdits: Bool { details != original }
    var canSave: Bool { !isSaving && workspaceID != nil && !details.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func reloadSaved() async {
        guard !isSaving, let existing else { return }
        isSaving = true; notice = nil
        defer { isSaving = false }
        do {
            let value = try await service.campaign(partnerID: existing.partnerID, campaignID: existing.id)
            self.existing = value; original = value.config; details = value.config
        } catch { notice = error.localizedDescription }
    }
    func save() async -> Bool {
        guard canSave, let workspaceID else { return false }
        isSaving = true; defer { isSaving = false }
        do {
            details.name = details.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing {
                savedCampaign = try await service.updateCampaign(partnerID: workspaceID, campaignID: existing.id, revision: existing.revision, details: details)
            } else {
                savedCampaign = try await service.createCampaign(partnerID: workspaceID, details: details)
            }
            return true
        } catch { notice = error.localizedDescription; return false }
    }
}
