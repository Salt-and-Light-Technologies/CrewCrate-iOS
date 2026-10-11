import Foundation

final class MemorySessionStore: AuthSessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var session: AuthSession?
    func load() throws -> AuthSession? { lock.lock(); defer { lock.unlock() }; return session }
    func save(_ value: AuthSession) throws { lock.lock(); defer { lock.unlock() }; session = value }
    func clear() throws { lock.lock(); defer { lock.unlock() }; session = nil }
}

actor AuthenticationTransport: LeadHTTPTransport {
    var requests: [URLRequest] = []
    var responses: [(Int, String)]
    init(_ responses: [(Int, String)]) { self.responses = responses }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let (status, body) = responses.removeFirst()
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

@main
struct AuthenticationChecks {
    static func check(_ condition: Bool) { precondition(condition) }
    static func main() async throws {
        let id = UUID()
        let token = "{\"access_token\":\"access\",\"refresh_token\":\"refresh\",\"expires_in\":3600,\"user\":{\"id\":\"\(id)\"}}"
        let me = "{\"user_id\":\"\(id)\",\"is_owner\":false}"
        let store = MemorySessionStore()
        let transport = AuthenticationTransport([(200, token), (200, me), (204, "")])
        let service = SupabaseSession(store: store, transport: transport)
        try await service.signIn(email: "user@example.com", password: "password")
        check(try store.load()?.userID == id)
        let identity = try await service.identity()
        check(identity.userID == id)
        let requests = await transport.requests
        check(requests[0].url?.query == "grant_type=password")
        check(requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer access")
        try await service.signOut()
        check(try store.load() == nil)

        let confirmationStore = MemorySessionStore()
        let confirmationTransport = AuthenticationTransport([(200, "{\"id\":\"\(id)\"}"), (200, "{}")])
        let confirmation = SupabaseSession(store: confirmationStore, transport: confirmationTransport)
        let signedIn = try await confirmation.signUp(email: "new@example.com", password: "password")
        check(!signedIn)
        check(try confirmationStore.load() == nil)
        try await confirmation.recover(email: "new@example.com")
        let confirmationRequests = await confirmationTransport.requests
        check(confirmationRequests[0].url?.path.hasSuffix("signup") == true)
        check(confirmationRequests[1].url?.path.hasSuffix("recover") == true)
        check(URLComponents(url: confirmationRequests[1].url!, resolvingAgainstBaseURL: false)?.queryItems?.first?.value == "crewcrate://auth")

        let refreshStore = MemorySessionStore()
        try refreshStore.save(AuthSession(accessToken: "expired", refreshToken: "old", expiresAt: .distantPast, userID: id))
        let refreshTransport = AuthenticationTransport([(200, token)])
        let refresh = SupabaseSession(store: refreshStore, transport: refreshTransport)
        let restored = try await refresh.restore()
        check(restored)
        let refreshRequests = await refreshTransport.requests
        check(refreshRequests[0].url?.query == "grant_type=refresh_token")
        check(try refreshStore.load()?.refreshToken == "refresh")

        let recoveryTransport = AuthenticationTransport([(200, "{\"id\":\"\(id)\"}"), (200, "{}")])
        let recovery = SupabaseSession(store: MemorySessionStore(), transport: recoveryTransport)
        let isRecovery = try await recovery.acceptCallback(URL(string: "crewcrate://auth#access_token=access&refresh_token=refresh&expires_in=3600&type=recovery")!)
        check(isRecovery)
        try await recovery.updatePassword("new-password")
        let recoveryRequests = await recoveryTransport.requests
        check(recoveryRequests[0].httpMethod == "GET")
        check(recoveryRequests[1].httpMethod == "PUT")
        check(recoveryRequests[1].value(forHTTPHeaderField: "Authorization") == "Bearer access")
        do {
            _ = try await recovery.acceptCallback(URL(string: "other://auth#access_token=access")!)
            fatalError("Unrelated callbacks must be rejected")
        } catch AuthError.response {}

        let rejected = SupabaseSession(store: MemorySessionStore(), transport: AuthenticationTransport([(400, "{}")]))
        do {
            try await rejected.signIn(email: "user@example.com", password: "wrong")
            fatalError("Invalid login must fail")
        } catch AuthError.credentials {}
        let profileJSON = "{\"id\":\"\(id)\",\"email\":\"user@example.com\",\"new_email\":\"new@example.com\",\"user_metadata\":{\"first_name\":\"Jamie\",\"last_name\":\"Lee\"}}"
        let campaignID = UUID()
        let campaignJSON = "{\"id\":\"\(campaignID)\",\"partner_id\":\"\(id)\",\"status\":\"draft\",\"config\":{\"name\":\"Roofing recovery\",\"offer\":\"Free inspection\",\"qualification\":\"\",\"handoff_email\":\"\"}}"
        let accountTransport = AuthenticationTransport([(200, token), (200, profileJSON), (200, profileJSON), (200, "[{\"id\":\"\(id)\",\"name\":\"Workspace\",\"status\":\"draft\"}]"), (200, "[\(campaignJSON)]"), (201, campaignJSON)])
        let account = SupabaseSession(store: MemorySessionStore(), transport: accountTransport)
        try await account.signIn(email: "user@example.com", password: "password")
        let profile = try await account.profile()
        check(profile.metadata?.firstName == "Jamie")
        let updated = try await account.updateProfile(firstName: "Jamie", lastName: "Lee", email: "new@example.com")
        check(updated.newEmail == "new@example.com")
        let spaces = try await account.workspaces()
        check(spaces.first?.id == id)
        let campaigns = try await account.campaigns(partnerID: id)
        check(campaigns.first?.config.name == "Roofing recovery")
        var details = CampaignDetails(); details.name = "Roofing recovery"; details.offer = "Free inspection"
        let saved = try await account.createCampaign(partnerID: id, details: details)
        check(saved.status == "draft")
        let accountRequests = await accountTransport.requests
        let updateBody = try JSONSerialization.jsonObject(with: accountRequests[2].httpBody!) as! [String: Any]
        check(updateBody["email"] as? String == "new@example.com")
        check((updateBody["data"] as? [String: String])?["first_name"] == "Jamie")
        check(accountRequests[2].httpMethod == "PUT")
        check(accountRequests[5].httpMethod == "POST")
        check(accountRequests[5].value(forHTTPHeaderField: "Authorization") == "Bearer access")
        let testID = UUID()
        let messageID = UUID()
        let decisionID = UUID()
        let testJSON = "{\"id\":\"\(testID)\",\"revision\":0,\"status\":\"active\",\"ai_name\":\"Emma\",\"messages\":[{\"id\":\"\(messageID)\",\"role\":\"assistant\",\"text\":\"Hello\",\"timestamp\":\"2026-10-11T00:00:00Z\"}],\"decisions\":[{\"id\":\"\(decisionID)\",\"decision\":\"continue\",\"reason\":\"Opening\",\"handoff_summary\":\"\"}]}"
        let aiTransport = AuthenticationTransport([(200, token), (201, testJSON), (200, testJSON), (200, testJSON)])
        let aiService = SupabaseSession(store: MemorySessionStore(), transport: aiTransport)
        try await aiService.signIn(email: "user@example.com", password: "password")
        let practice = try await aiService.startAITest(partnerID: id, campaignID: nil, config: details)
        check(practice.isActive && practice.aiName == "Emma" && practice.messages.count == 1)
        let turnID = UUID()
        _ = try await aiService.sendAITest(partnerID: id, testID: practice.id, revision: 0, requestID: turnID, text: "Is it free?")
        _ = try await aiService.aiTest(partnerID: id, testID: practice.id)
        let aiRequests = await aiTransport.requests
        let startBody = try JSONSerialization.jsonObject(with: aiRequests[1].httpBody!) as! [String: Any]
        check(startBody["config"] != nil && startBody["campaign_id"] == nil)
        let turnBody = try JSONSerialization.jsonObject(with: aiRequests[2].httpBody!) as! [String: Any]
        check(turnBody["expected_revision"] as? Int == 0)
        check(turnBody["request_id"] as? String == turnID.uuidString)
        check(aiRequests[3].httpMethod == "GET")
        print("Authentication checks passed (mock services; no live accounts or emails).")
    }
}
