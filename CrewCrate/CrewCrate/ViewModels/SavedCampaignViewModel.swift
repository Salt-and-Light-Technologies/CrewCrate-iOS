import Foundation
import Observation

@MainActor
@Observable
final class SavedCampaignViewModel {
    var campaign: CampaignSummary
    var showsEditor = false
    var showsTest = false
    var isLoading = false
    var notice: String?
    var error: String?
    let service: any CampaignServicing
    init(campaign: CampaignSummary, service: any CampaignServicing) {
        self.campaign = campaign; self.service = service
    }
    var canEdit: Bool { !isLoading && !["paused", "archived"].contains(campaign.status) }
    func load() async {
        guard !isLoading else { return }
        isLoading = true; error = nil
        defer { isLoading = false }
        do { campaign = try await service.campaign(partnerID: campaign.partnerID, campaignID: campaign.id) }
        catch { self.error = error.localizedDescription }
    }
    var canPrepare: Bool { canEdit && campaign.ownerHold != true && !campaign.config.leadIDs.isEmpty }
    var canStart: Bool { canPrepare && campaign.status == "ready_to_connect" && (campaign.blockers ?? []).isEmpty }
    func prepare() async -> CampaignSummary? {
        guard canPrepare else { return nil }
        isLoading = true; error = nil; notice = nil
        defer { isLoading = false }
        do {
            campaign = try await service.prepareCampaign(partnerID: campaign.partnerID, campaignID: campaign.id, revision: campaign.revision)
            notice = "Campaign checked and ready to connect. SMS provider connection is still required."
            return campaign
        } catch { self.error = error.localizedDescription; return nil }
    }
    func showSMSConnectionNotice() {
        notice = "SMS connection is pending. You can keep editing your campaign and testing the AI. Connect an SMS provider when you’re ready to send messages."
    }
    func start() async {
        guard canStart else { return }
        isLoading = true; error = nil; notice = nil
        defer { isLoading = false }
        do {
            try await service.startCampaign(partnerID: campaign.partnerID, campaignID: campaign.id, revision: campaign.revision)
            notice = "Start request accepted."
        } catch { notice = error.localizedDescription }
    }
    func removeLeadList() async -> CampaignSummary? {
        guard canEdit && campaign.ownerHold != true else { return nil }
        isLoading = true; error = nil
        defer { isLoading = false }
        do {
            var config = campaign.config
            config.leadIDs = []
            campaign = try await service.updateCampaign(partnerID: campaign.partnerID, campaignID: campaign.id,
                revision: campaign.revision, details: config)
            return campaign
        } catch { self.error = error.localizedDescription; return nil }
    }
    func didSave(_ updated: CampaignSummary) { campaign = updated; error = nil }
}
