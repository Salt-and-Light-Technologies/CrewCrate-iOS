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
        UploadColumns(columns: ["Phone", "Name", "Email"], sheets: [], selected_sheet: nil)
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
        let original = sampleCampaign(originalSettings, business: business.id)
        let editor = CampaignEditorModel(business: business, original: original, service: service, reader: ReaderFake())
        editor.settings.name = "New name"
        _ = await editor.save()
        let sentSettings = await service.savedSettings
        precondition(sentSettings?.lead_ids == originalSettings.lead_ids)
        precondition(sentSettings?.daily_limit == 72 && sentSettings?.start_minute == 30)
        await editor.selectFile(URL(fileURLWithPath: "/private/tmp/contacts.csv"))
        precondition(editor.mapping.phone == "Phone" && !editor.canSave)
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
        await editor.reloadSaved()
        precondition(!editor.saveOutcomeUnknown && editor.settings.name == "Server version")

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
        _ = try await session.saveUpload(business: business.id, original: original, settings: originalSettings,
            upload: upload, mapping: UploadMapping(phone: "Phone"), preview: preview)
        let multipart = await transport.requests[1]
        let body = String(decoding: multipart.httpBody!, as: UTF8.self)
        precondition(multipart.url!.path.hasSuffix("/campaign-import"))
        precondition(body.contains("name=\"expected_partner_revision\"\r\n\r\n9"))
        precondition(body.contains("name=\"campaign_id\""))

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
        print("Campaign editing, upload preview, retry and HTTP contract checks passed.")
    }
}
