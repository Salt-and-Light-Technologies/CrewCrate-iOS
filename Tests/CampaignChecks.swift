import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

nonisolated struct CampaignTestToken: APITokenProvider { func accessToken() async throws -> String { "test-token" } }
actor CampaignTestHTTP: LeadHTTPTransport {
    private var response = Data()
    private var request: URLRequest?
    func respond(_ object: Any) throws { response = try JSONSerialization.data(withJSONObject: object) }
    func last() -> URLRequest? { request }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        self.request = request
        return (response, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@main struct CampaignChecks {
    @MainActor static func main() async throws {
        func check(_ value: Bool, _ message: String) { precondition(value, message) }
        let repo = DemoPartnerRepository(campaignDemo: true)
        let partnerID = DemoPartnerFixtures.make()[0].id
        let leads = try await repo.leads(partnerID: partnerID, search: "", status: .eligible, offset: 0)
        let allowed = leads.first { $0.smsPermission == "recorded" }!
        let unknown = leads.first { $0.smsPermission == "unknown" }!
        var config = CampaignConfig(name: "Recovery pilot", offer: "Reconnect", messageTemplate: "", qualification: "Interested and in service area", handoffEmail: "sales@example.com", timeZone: "America/Chicago", leadIDs: [allowed.id])
        config.aiName = "Emma"
        config.aiBrief = "Reconnect dormant leads about our promotion and book a consultation."
        let created = try await repo.saveCampaign(partnerID: partnerID, id: nil, config: config, expectedRevision: nil)
        check(created.blockers.isEmpty && created.status == .draft, "Self-service draft readiness")
        let prepared = try await repo.prepareCampaign(partnerID: partnerID, id: created.id, expectedRevision: created.revision)
        check(prepared.status == .readyToConnect && prepared.recipientCount == 1, "Preparation without owner campaign approval")
        do { _ = try await repo.prepareCampaign(partnerID: partnerID, id: created.id, expectedRevision: 1); fatalError("Stale preparation allowed") }
        catch CampaignError.conflict {}
        config.leadIDs = [unknown.id]
        let blocked = try await repo.saveCampaign(partnerID: partnerID, id: nil, config: config, expectedRevision: nil)
        check(!blocked.blockers.isEmpty, "Unknown permission blocked")
        do { _ = try await repo.prepareCampaign(partnerID: partnerID, id: blocked.id, expectedRevision: blocked.revision); fatalError("Unknown permission prepared") }
        catch CampaignError.invalid {}
        _ = try await repo.setPermission(partnerID: partnerID, leadID: allowed.id, permission: "revoked", evidence: "Sample opt-out reference", expectedRevision: allowed.revision)
        let invalidated = try await repo.campaign(partnerID: partnerID, id: created.id)
        check(invalidated.needsRecheck && invalidated.recipientCount == 0, "Readiness invalidated by opt-out")
        do { _ = try await repo.setPermission(partnerID: partnerID, leadID: allowed.id, permission: "recorded", evidence: "Attempted reactivation", expectedRevision: 1); fatalError("Opt-out overridden") }
        catch CampaignError.invalid {}
        let paused = try await repo.controlCampaign(partnerID: partnerID, id: created.id, action: "pause", reason: "Review the plan", expectedRevision: prepared.revision)
        check(paused.status == .paused, "Pause control")
        let resumed = try await repo.controlCampaign(partnerID: partnerID, id: created.id, action: "resume", reason: "Resume planning", expectedRevision: paused.revision)
        check(resumed.status == .draft && resumed.preparedPartnerRevision == nil, "Resume resets preparation")
        do { _ = try await repo.campaign(partnerID: UUID(), id: created.id); fatalError("Cross-partner campaign exposed") }
        catch CampaignError.missing {}
        config.dailyLimit = 1000
        check(CampaignValidation.draftIssues(config).isEmpty, "Manually entered limits above 100 must be supported")
        config.dailyLimit = 0
        do { _ = try await repo.saveCampaign(partnerID: partnerID, id: nil, config: config, expectedRevision: nil); fatalError("Zero daily limit accepted") }
        catch CampaignError.invalid {}
        config.dailyLimit = 25
        let conversation = try await repo.trackConversation(partnerID: partnerID, campaignID: blocked.id, leadID: unknown.id, note: "Internal manual follow-up")
        let updated = try await repo.updateConversation(partnerID: partnerID, campaignID: blocked.id, id: conversation.id, status: .handoff, note: "Team will follow up manually", expectedRevision: 0)
        check(updated.status == .handoff && updated.revision == 1, "Manual tracking")
        do { _ = try await repo.updateConversation(partnerID: partnerID, campaignID: blocked.id, id: conversation.id, status: .closed, note: "Outdated update", expectedRevision: 0); fatalError("Stale tracking updated") }
        catch CampaignError.conflict {}
        let notes = try await repo.conversationHistory(partnerID: partnerID, campaignID: blocked.id, id: conversation.id, offset: 0)
        check(notes.count == 2 && notes[0].status == .handoff, "Attributable notes")
        let fresh = DemoPartnerRepository(campaignDemo: true)
        let vm = CampaignEditorViewModel(partnerID: partnerID, id: nil, repository: fresh, leads: fresh, isDemo: true)
        await vm.load(); vm.useSamplePlan(); await vm.prepare()
        check(vm.record?.status == .readyToConnect && vm.notice != nil, "Editor prepare flow")
        vm.config.offer = "Unsaved edit"
        await vm.load()
        check(vm.config.offer == "Unsaved edit" && vm.errorMessage != nil, "Refresh preserves unsaved edits")
        await vm.load(discardEdits: true)
        check(vm.config.offer != "Unsaved edit", "Explicit discard")
        let tracking = vm.conversations()!
        tracking.selectedLead = vm.config.leadIDs[0]; tracking.note = "Manually recorded interest"
        await tracking.create()
        check(tracking.records.count == 1 && tracking.errorMessage == nil, "Tracking view model")
        let detail = tracking.detail(tracking.records[0])
        await detail.load(); detail.status = .interested; detail.note = "Internal interest noted"; await detail.save()
        check(detail.record.status == .interested && detail.notes.count == 2, "Tracking detail view model")

        let transport = CampaignTestHTTP()
        let api = try APILeadRepository(baseURL: URL(string: "https://crewcrate.example.com")!, tokens: CampaignTestToken(), ownerWorkspace: true, transport: transport)
        let wireConfig: [String: Any] = ["ai_name": "Emma", "ai_brief": config.aiBrief!,"name":"Recovery pilot","offer":"Reconnect","message_template":"Message draft","qualification":"Interested","handoff_email":"sales@example.com","time_zone":"America/Chicago","start_hour":9,"end_hour":17,"daily_limit":25,"follow_up_limit":1,"lead_ids":[allowed.id.uuidString]]
        let wireCampaign: [String: Any] = ["id":created.id.uuidString,"partner_id":partnerID.uuidString,"status":"draft","revision":1,"config":wireConfig,"updated_at":"2026-10-08T19:00:00.123456Z","blockers":[],"recipient_count":1,"messaging_connected":false,"sending_enabled":false,"needs_recheck":false]
        try await transport.respond(wireCampaign)
        config.leadIDs = [allowed.id]
        let remote = try await api.saveCampaign(partnerID: partnerID, id: nil, config: config, expectedRevision: nil)
        check(remote.config.aiName == "Emma", "AI name must survive API decoding")
        check(remote.config.aiBrief == config.aiBrief, "AI brief must survive API decoding")
        check(remote.config.leadIDs == [allowed.id] && remote.status == .draft, "Campaign wire decoding")
        let request = await transport.last()!
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        check(body["ai_name"] as? String == "Emma", "AI name must be saved to the backend")
        check(body["ai_brief"] as? String == config.aiBrief, "AI brief must be sent to backend")
        check(body["lead_ids"] as? [String] == [allowed.id.uuidString] && body["follow_up_limit"] as? Int == 1, "Campaign wire encoding")
        check(request.httpMethod == "POST" && request.url!.path.hasSuffix("/campaigns"), "Creation route")
        _ = try await api.prepareCampaign(partnerID: partnerID, id: created.id, expectedRevision: 1)
        let preparation = await transport.last()!
        check(preparation.url!.path.hasSuffix("/prepare"), "Preparation route")
        try await transport.respond(["id":conversation.id.uuidString,"campaign_id":blocked.id.uuidString,"lead_id":unknown.id.uuidString,"status":"handoff","revision":1,"updated_at":"2026-10-08T19:00:00Z","source":"manual_tracking"])
        let remoteTracking = try await api.updateConversation(partnerID: partnerID, campaignID: blocked.id, id: conversation.id, status: .handoff, note: "Internal tracking", expectedRevision: 0)
        check(remoteTracking.status == .handoff && remoteTracking.leadID == unknown.id, "Tracking wire mapping")
        let mutation = await transport.last()!
        check(mutation.httpMethod == "PATCH", "Tracking mutation route")
        let pagingRepo = DemoPartnerRepository()
        let pagingID = DemoPartnerFixtures.make()[0].id
        let csv = "Phone,Name\n" + (0..<600).map { "1202555\(String(format: "%04d", $0 + 100)),Person \($0)" }.joined(separator: "\n")
        let doc = try CSVParser.parse(data: Data(csv.utf8), fileName: "large-list.csv")
        let mapping = LeadColumnMapping(phone: 0, name: 1)
        let preview = try await pagingRepo.preview(partnerID: pagingID, document: doc, mapping: mapping)
        _ = try await pagingRepo.importLeads(partnerID: pagingID, document: doc, mapping: mapping, expectedRevision: preview.partnerRevision)
        let editor = CampaignEditorViewModel(partnerID: pagingID, id: nil, repository: pagingRepo, leads: pagingRepo, isDemo: true)
        await editor.load()
        check(editor.candidates.count == 50 && editor.candidatesTruncated, "Opening editor must fetch just the first contact page")
        check(!editor.blocksEditing, "New campaign form must remain editable after initial loading")
        await editor.loadMoreCandidates()
        check(editor.candidates.count == 100, "Additional contact pages must load on demand")
        print("Campaign checks passed: self-service preparation, permission gates, opt-outs, revisions, controls, manual tracking, unsaved edits and API contracts.")
    }
}
