import Foundation

nonisolated private func sampleCampaign(_ settings: CampaignSettings, business: UUID, revision: Int = 3) -> WorkspaceCampaign {
    WorkspaceCampaign(id: UUID(), partner_id: business, status: "draft", revision: revision, config: settings,
        blockers: ["Choose campaign recipients"], recipient_count: 0, needs_recheck: false,
        owner_hold: false, messaging_connected: false, sending_enabled: false)
}

private actor WorkspaceFake: CampaignWorkspaceServicing {
    let business: UUID
    var failSave = false
    var failReply = true
    var attempts: [UUID] = []
    var savedSettings: CampaignSettings?
    let conversationID = UUID()
    init(business: UUID) { self.business = business }
    func campaigns(business: UUID) async throws -> [WorkspaceCampaign] { [] }
    func campaign(business: UUID, id: UUID) async throws -> WorkspaceCampaign {
        var settings = CampaignSettings(); settings.name = "Server version"
        return sampleCampaign(settings, business: business)
    }
    func saveCampaign(business: UUID, original: WorkspaceCampaign?, settings: CampaignSettings) async throws -> WorkspaceCampaign {
        if failSave { throw URLError(.networkConnectionLost) }
        savedSettings = settings
        return sampleCampaign(settings, business: business)
    }
    func startPractice(business: UUID, settings: CampaignSettings) async throws -> PracticeConversation {
        PracticeConversation(id: conversationID, revision: 0, status: "active", ai_name: settings.ai_name ?? "Emma",
            messages: [], decisions: [])
    }
    func practice(business: UUID, id: UUID) async throws -> PracticeConversation {
        PracticeConversation(id: id, revision: 0, status: "active", ai_name: "Emma", messages: [], decisions: [])
    }
    func reply(business: UUID, conversation: UUID, revision: Int, request: UUID, text: String) async throws -> PracticeConversation {
        attempts.append(request)
        if failReply { failReply = false; throw URLError(.timedOut) }
        return PracticeConversation(id: conversation, revision: revision + 1, status: "handoff", ai_name: "Emma",
            messages: [PracticeMessage(id: UUID(), role: "user", text: text, request_id: request)], decisions: [])
    }
    func columns(business: UUID, upload: ContactUpload, sheet: String) async throws -> UploadColumns {
        UploadColumns(columns: ["Phone", "Name", "Email", "SMS permission", "Permission evidence", "Opted out"], sheets: [], selected_sheet: nil)
    }
    func preview(business: UUID, upload: ContactUpload, mapping: UploadMapping) async throws -> UploadPreview {
        UploadPreview(partner_revision: 7, total_rows: 2, imported: 1, duplicates: 0, invalid: 1,
            issues: [], issues_truncated: false)
    }
    func saveUpload(business: UUID, original: WorkspaceCampaign?, settings: CampaignSettings,
                    upload: ContactUpload, mapping: UploadMapping, preview: UploadPreview) async throws -> WorkspaceCampaign {
        savedSettings = settings
        return sampleCampaign(settings, business: business)
    }
    func setSaveFailure() { failSave = true }
}

private actor ReaderFake: ContactUploadReading {
    func read(_ url: URL) async throws -> ContactUpload {
        ContactUpload(filename: "contacts.csv", data: Data("Phone,Name\n15551234567,Sam".utf8))
    }
}
private actor OwnerAnalyticsFake: OwnerAnalyticsServicing {
    let response: OwnerBusinessAnalytics
    init(response: OwnerBusinessAnalytics) { self.response = response }
    func ownerAnalytics(business: UUID) async throws -> OwnerBusinessAnalytics { response }
}
nonisolated private struct SessionStoreFake: AuthSessionStore {
    let session: AuthSession
    func load() throws -> AuthSession? { session }
    func save(_ session: AuthSession) throws { }
    func clear() throws { }
}
private actor TransportFake: LeadHTTPTransport {
    var requests: [URLRequest] = []
    let response: Data
    init(response: Data) { self.response = response }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return (response, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@main
struct CampaignWorkspaceChecks {
    @MainActor static func main() async throws {
        let business = BusinessSummary(id: UUID(), name: "Bob's Roofing", status: "draft", revision: 0)
        let service = WorkspaceFake(business: business.id)
        var originalSettings = CampaignSettings()
        originalSettings.name = "Old name"
        originalSettings.lead_ids = [UUID()]
        originalSettings.daily_limit = 72
        originalSettings.start_minute = 30
        originalSettings.start_date = "2026-10-12"
        originalSettings.end_date = "2026-10-19"
        let encodedPlan = try JSONEncoder().encode(originalSettings)
        let decodedPlan = try JSONDecoder().decode(CampaignSettings.self, from: encodedPlan)
        precondition(decodedPlan.start_date == "2026-10-12" && decodedPlan.end_date == "2026-10-19")
        var legacyJSON = try JSONSerialization.jsonObject(with: encodedPlan) as! [String: Any]
        legacyJSON.removeValue(forKey: "start_date"); legacyJSON.removeValue(forKey: "end_date")
        let legacyPlan = try JSONDecoder().decode(CampaignSettings.self,
            from: JSONSerialization.data(withJSONObject: legacyJSON))
        precondition(legacyPlan.start_date == nil && legacyPlan.end_date == nil)
        let original = sampleCampaign(originalSettings, business: business.id)
        let editor = CampaignEditorModel(business: business, original: original, service: service, reader: ReaderFake())
        editor.settings.ai_name = "Old custom name"
        precondition(editor.designatedAIName == "Old custom name")
        editor.designatedAIName = "Olivia"
        _ = await editor.save()
        let selectedIdentity = await service.savedSettings
        precondition(selectedIdentity?.ai_name == "Olivia")
        editor.settings.ai_name = nil
        precondition(editor.designatedAIName == "AI Assistant")
        editor.settings.ai_name = "   "
        precondition(editor.designatedAIName == "AI Assistant")
        editor.settings = originalSettings
        precondition(editor.hasDateRange)
        let selectedDate = editor.campaignDate(isStart: true)
        editor.settings.time_zone = "Pacific/Auckland"
        precondition(editor.campaignDate(isStart: true) == selectedDate)
        editor.setCampaignDate(editor.campaignDate(isStart: false), isStart: true)
        precondition(editor.canSave) // Same-day inclusive range is valid.
        editor.settings.end_date = "2026-10-12"
        precondition(!editor.canSave && editor.sendingPlanError != nil)
        editor.setDateRangeEnabled(false)
        precondition(!editor.hasDateRange && editor.canSave)
        editor.setDateRangeEnabled(true)
        precondition(editor.hasDateRange && editor.canSave)
        editor.settings = originalSettings
        // Direct numeric entry rejects incomplete/out-of-range/pasted invalid text
        // without silently submitting the old value, then recovers on a valid edit.
        for text in ["", "0", "1001", "-1", "1.5", "abc", "999999999999999999999999"] {
            editor.dailyLimitInput = text
            precondition(!editor.canSave && editor.sendingPlanError != nil)
            precondition(editor.settings.daily_limit == 72)
        }
        editor.dailyLimitInput = "1000"
        precondition(editor.canSave && editor.settings.daily_limit == 1000)
        _ = await editor.save()
        let boundarySettings = await service.savedSettings
        precondition(boundarySettings?.daily_limit == 1000)
        editor.dailyLimitInput = "1001"
        precondition(!editor.canSave && editor.settings.daily_limit == 1000)
        editor.dailyLimitInput = "1"
        precondition(editor.canSave && editor.settings.daily_limit == 1)
        for text in ["", "4", "-1", "2.5", "abc"] {
            editor.followUpInput = text
            precondition(!editor.canSave && editor.settings.follow_up_limit == 1)
        }
        editor.followUpInput = "0"
        precondition(editor.canSave && editor.settings.follow_up_limit == 0)
        editor.followUpInput = "3"
        precondition(editor.canSave && editor.settings.follow_up_limit == 3)
        let startClock = editor.sendingTime(isStart: true)
        editor.settings.time_zone = "America/Los_Angeles"
        precondition(editor.sendingTime(isStart: true) == startClock)
        editor.setSendingTime(startClock, isStart: false)
        precondition(!editor.canSave) // Equal start/end is an invalid window.
        editor.setSendingTime(editor.sendingTimeRange.upperBound, isStart: false)
        precondition(editor.settings.end_hour == 17 && editor.settings.end_minute == 0 && editor.canSave)
        let parts = editor.sendingPlanCalendar.dateComponents([.hour, .minute], from: startClock)
        precondition(parts.hour == 9 && parts.minute == 30)
        editor.settings = originalSettings
        editor.dailyLimitInput = nil; editor.followUpInput = nil
        editor.settings.name = "New name"
        _ = await editor.save()
        let sentSettings = await service.savedSettings
        precondition(sentSettings?.lead_ids == originalSettings.lead_ids)
        precondition(sentSettings?.daily_limit == 72 && sentSettings?.start_minute == 30)
        precondition(sentSettings?.start_date == "2026-10-12" && sentSettings?.end_date == "2026-10-19")
        await editor.selectFile(URL(fileURLWithPath: "/private/tmp/contacts.csv"))
        precondition(editor.mapping.phone == "Phone" && !editor.canSave)
        precondition(editor.mapping.permission == "SMS permission" && editor.mapping.evidence == "Permission evidence")
        precondition(editor.mapping.optout == "Opted out" && !editor.mapping.permissionAttested)
        editor.mapping.permissionAttested = true
        await editor.previewUpload()
        precondition(editor.canSave)
        editor.mapping.name = "Email"
        precondition(!editor.canSave) // mapping change invalidates snapshot even before the view's onChange
        editor.invalidatePreview()
        precondition(editor.preview == nil)
        editor.removeUpload()
        precondition(editor.canSave)
        await service.setSaveFailure()
        _ = await editor.save()
        precondition(editor.saveOutcomeUnknown && !editor.canSave && editor.settings.name == "New name")
        editor.dailyLimitInput = ""
        await editor.reloadSaved()
        precondition(!editor.saveOutcomeUnknown && editor.settings.name == "Server version")
        precondition(editor.dailyLimitInput == nil && editor.followUpInput == nil && editor.canSave)

        let practice = PracticeConversationModel(business: business.id, settings: originalSettings, service: service)
        await practice.start()
        practice.replyText = "I want to talk to a person"
        await practice.send()
        precondition(practice.needsRetry && practice.replyText == "I want to talk to a person")
        await practice.send()
        let attempts = await service.attempts
        precondition(attempts.count == 2 && attempts[0] == attempts[1])
        precondition(!practice.canReply && !practice.needsRetry && practice.replyText.isEmpty)

        let transport = TransportFake(response: try JSONEncoder().encode(original))
        let session = SupabaseSession(store: SessionStoreFake(session: AuthSession(accessToken: "test-token",
            refreshToken: "test-refresh", expiresAt: Date().addingTimeInterval(3600), userID: UUID())), transport: transport)
        _ = try await session.restore()
        _ = try await session.saveCampaign(business: business.id, original: original, settings: originalSettings)
        let request = await transport.requests[0]
        precondition(request.httpMethod == "PUT" && request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        let json = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        precondition(json["expected_revision"] as? Int == original.revision)
        let upload = ContactUpload(filename: "contacts.csv", data: Data("Phone\n15551234567".utf8))
        let preview = UploadPreview(partner_revision: 9, total_rows: 1, imported: 1, duplicates: 0, invalid: 0,
            issues: [], issues_truncated: false)
        let permissionMapping = UploadMapping(phone: "Phone", permission: "SMS permission",
            evidence: "Permission evidence", optout: "Opted out", permissionAttested: true)
        _ = try await session.saveUpload(business: business.id, original: original, settings: originalSettings,
            upload: upload, mapping: permissionMapping, preview: preview)
        let multipart = await transport.requests[1]
        let body = String(decoding: multipart.httpBody!, as: UTF8.self)
        precondition(multipart.url!.path.hasSuffix("/campaign-import"))
        precondition(body.contains("name=\"expected_partner_revision\"\r\n\r\n9"))
        precondition(body.contains("name=\"campaign_id\""))
        precondition(body.contains("name=\"eligible_recipients_only\"\r\n\r\ntrue"))
        precondition(body.contains("\"permission\":\"SMS permission\""))
        precondition(body.contains("\"evidence\":\"Permission evidence\""))
        precondition(body.contains("\"optout\":\"Opted out\""))
        precondition(body.contains("name=\"permission_attested\"\r\n\r\ntrue"))
        let previewJSON = Data("{\"partner_revision\":9,\"total_rows\":1,\"imported\":1,\"duplicates\":0,\"invalid\":0,\"issues\":[],\"issues_truncated\":false,\"eligible_count\":0,\"excluded_count\":1,\"contacts\":[],\"contacts_truncated\":false}".utf8)
        let previewTransport = TransportFake(response: previewJSON)
        let previewSession = SupabaseSession(store: SessionStoreFake(session: AuthSession(accessToken: "test-token",
            refreshToken: "test-refresh", expiresAt: Date().addingTimeInterval(3600), userID: UUID())), transport: previewTransport)
        _ = try await previewSession.restore()
        let permissionPreview = try await previewSession.preview(business: business.id, upload: upload, mapping: permissionMapping)
        precondition(permissionPreview.eligible_count == 0 && permissionPreview.excluded_count == 1)
        let previewRequest = await previewTransport.requests[0]
        let previewBody = String(decoding: previewRequest.httpBody!, as: UTF8.self)
        precondition(previewBody.contains("\"permission\":\"SMS permission\""))
        precondition(previewBody.contains("\"evidence\":\"Permission evidence\""))
        precondition(previewBody.contains("\"optout\":\"Opted out\""))
        precondition(previewBody.contains("name=\"permission_attested\"\r\n\r\ntrue"))

        let optedOut = WorkspaceContact(id: UUID(), name: "Sam", phone: "13125550123", email: "sam@example.com",
            status: "excluded", revision: 4, sms_permission: "revoked", permission_evidence: "Asked to stop",
            opted_out: true, exclusion_reasons: ["Contact opted out"])
        let contactTransport = TransportFake(response: try JSONEncoder().encode(optedOut))
        let contactSession = SupabaseSession(store: SessionStoreFake(session: AuthSession(accessToken: "test-token",
            refreshToken: "test-refresh", expiresAt: Date().addingTimeInterval(3600), userID: UUID())), transport: contactTransport)
        _ = try await contactSession.restore()
        let permission = ContactPermissionEditorModel(contact: optedOut, business: business.id, service: contactSession)
        permission.fields.action = "record_permission"
        permission.fields.evidence = "signed form reference"
        permission.fields.source = "signed form"
        permission.fields.attested = true
        precondition(!permission.canSave) // even a complete form cannot re-enable an opted-out lead
        permission.fields.action = "exclude"
        precondition(permission.canSave)
        _ = await permission.save()
        let reviewRequest = await contactTransport.requests[0]
        let reviewJSON = try JSONSerialization.jsonObject(with: reviewRequest.httpBody!) as! [String: Any]
        precondition(reviewJSON["expected_revision"] as? Int == 4)
        precondition(reviewJSON["action"] as? String == "exclude")
        precondition(reviewRequest.url!.path.contains(business.id.uuidString))
        var profileFields = BusinessProfileFields()
        profileFields.business_name = business.name
        profileFields.services = "Roof repairs"
        var profileObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(profileFields)) as! [String: Any]
        profileObject["offer"] = "Preserve this unrelated onboarding field"
        let profileTransport = TransportFake(response: try JSONSerialization.data(withJSONObject: [
            "id": business.id.uuidString, "revision": 5, "onboarding": profileObject]))
        let profileSession = SupabaseSession(store: SessionStoreFake(session: AuthSession(accessToken: "test-token",
            refreshToken: "test-refresh", expiresAt: Date().addingTimeInterval(3600), userID: UUID())), transport: profileTransport)
        _ = try await profileSession.restore()
        let profile = BusinessProfileEditorModel(business: business, service: profileSession)
        await profile.load()
        precondition(profile.hasLoaded && profile.fields.services == "Roof repairs")
        profile.fields.services = "Roof repairs and inspections"
        precondition(profile.hasEdits && profile.canSave)
        await profile.save()
        let profileRequest = await profileTransport.requests[1]
        let profileJSON = try JSONSerialization.jsonObject(with: profileRequest.httpBody!) as! [String: Any]
        precondition(profileRequest.httpMethod == "PUT" && profileJSON["expected_revision"] as? Int == 5)
        precondition(profileJSON["offer"] == nil) // profile edits leave unrelated fields to server-side preservation
        let analyticsData = try JSONSerialization.data(withJSONObject: [
            "partner_id": business.id.uuidString, "name": business.name, "access_approved": true,
            "total_contacts": 12, "import_count": 2, "campaign_count": 0,
            "campaign_status_counts": [:], "lead_status_counts": ["unreviewed": 12],
            "manual_conversation_count": 0, "manual_status_counts": [:], "sms_connected": false,
        ])
        let analytics = try JSONDecoder().decode(OwnerBusinessAnalytics.self, from: analyticsData)
        let ownerModel = OwnerBusinessAnalyticsModel(business: business,
            analyticsService: OwnerAnalyticsFake(response: analytics), campaignService: service)
        await ownerModel.load()
        precondition(ownerModel.analytics?.total_contacts == 12 && ownerModel.analyticsError == nil)
        precondition(ownerModel.campaigns.isEmpty && !ownerModel.isLoading)
        let analyticsTransport = TransportFake(response: analyticsData)
        let analyticsSession = SupabaseSession(store: SessionStoreFake(session: AuthSession(accessToken: "test-token",
            refreshToken: "test-refresh", expiresAt: Date().addingTimeInterval(3600), userID: UUID())), transport: analyticsTransport)
        _ = try await analyticsSession.restore()
        _ = try await analyticsSession.ownerAnalytics(business: business.id)
        let analyticsRequest = await analyticsTransport.requests[0]
        precondition(analyticsRequest.httpMethod == "GET")
        precondition(analyticsRequest.url!.path == "/v1/owner/partners/\(business.id)/analytics")
        print("Campaign editing, upload preview, retry and HTTP contract checks passed.")
    }
}
