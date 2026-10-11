import Foundation

nonisolated final class TestSessionStore: AuthSessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var value: AuthSession?
    init(_ value: AuthSession? = nil) { self.value = value }
    func load() throws -> AuthSession? { lock.lock(); defer { lock.unlock() }; return value }
    func save(_ session: AuthSession) throws { lock.lock(); defer { lock.unlock() }; value = session }
    func clear() throws { lock.lock(); defer { lock.unlock() }; value = nil }
}
actor MockTransport: LeadHTTPTransport {
    var requests: [URLRequest] = []
    let user = UUID(uuidString: "5a38c5d5-dfa8-4997-a63c-c898b0b326d8")!
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let path = request.url!.path
        var object: [String: Any] = [:]
        if path.hasSuffix("token") {
            try await Task.sleep(for: .milliseconds(20))
            object = ["access_token": "fresh-access", "refresh_token": "rotated-refresh", "expires_in": 3600, "user": ["id": user.uuidString]]
        } else if path.hasSuffix("logout") { object = [:] }
        else if request.httpMethod == "PUT" || path.hasSuffix("submit") {
            object = ["revision": 5]
        } else {
            object = ["revision": 4, "status": "draft", "onboarding": ["business_name": "Bright Dental", "booking_url": "https://example.com/book", "team_emails": ["sales@example.com"], "audience": ["dormant"], "goal": "handoff", "evidence_source": "crm", "compensation": "hybrid"]]
        }
        return (try JSONSerialization.data(withJSONObject: object), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    func captured() -> [URLRequest] { requests }
}
struct FixedToken: APITokenProvider { func accessToken() async throws -> String { "test-access" } }
@main struct AuthChecks {
    static func main() async throws {
        let transport = MockTransport()
        let uid = UUID(uuidString: "5a38c5d5-dfa8-4997-a63c-c898b0b326d8")!
        let store = TestSessionStore(AuthSession(accessToken: "expired", refreshToken: "old-refresh", expiresAt: .distantPast, userID: uid))
        let auth = SupabaseSession(store: store, transport: transport)
        let restored = try await auth.restore(); assert(restored)
        let stored = try store.load(); assert(stored?.refreshToken == "rotated-refresh")
        try await auth.signOut()
        let cleared = try store.load(); assert(cleared == nil)
        do { _ = try await auth.accessToken(); fatalError("Signed out token leaked") } catch AuthError.signedOut { }
        try await auth.signIn(email: "owner@example.com", password: "test-password")
        let access = try await auth.accessToken(); assert(access == "fresh-access")
        let request = await transport.captured().first!
        assert(request.value(forHTTPHeaderField: "apikey") == LiveConfiguration.publishableKey)
        assert(request.url!.query == "grant_type=refresh_token")
        let concurrentTransport = MockTransport()
        let concurrentAuth = SupabaseSession(store: TestSessionStore(AuthSession(accessToken: "valid", refreshToken: "old-refresh", expiresAt: .distantFuture, userID: uid)), transport: concurrentTransport)
        _ = try await concurrentAuth.restore()
        // Seed an expiring restored session, then join concurrent refresh requests.
        let expiringStore = TestSessionStore(AuthSession(accessToken: "valid", refreshToken: "old-refresh", expiresAt: Date().addingTimeInterval(61), userID: uid))
        let refreshAuth = SupabaseSession(store: expiringStore, transport: concurrentTransport)
        _ = try await refreshAuth.restore()
        try await Task.sleep(for: .seconds(1.1))
        async let a = refreshAuth.accessToken(); async let b = refreshAuth.accessToken()
        let tokens = try await (a,b)
        assert(tokens.0 == tokens.1)
        let captured = await concurrentTransport.captured(); assert(captured.filter { $0.url!.path.hasSuffix("token") }.count == 1)
        let api = try APILeadRepository(baseURL: LiveConfiguration.apiURL, tokens: FixedToken(), ownerWorkspace: false, transport: transport)
        let onboarding = LiveOnboardingStore(api: api, partnerID: UUID())
        guard let draft = try await onboarding.load() else { fatalError("No draft") }
        assert(draft.businessName == "Bright Dental" && draft.bookingURL == "https://example.com/book")
        assert(draft.goal == .handoff && draft.evidenceSource == .crm && draft.compensation == .hybrid)
        assert(draft.teamEmails == "sales@example.com" && draft.audience == [.dormant])
        try await onboarding.save(draft)
        let save = await transport.captured().last!
        let payload = try JSONSerialization.jsonObject(with: save.httpBody!) as! [String: Any]
        let setup = payload["onboarding"] as! [String: Any]
        assert(setup["booking_url"] as? String == draft.bookingURL)
        assert(setup["goal"] as? String == "handoff")
        assert(setup["team_emails"] as? [String] == ["sales@example.com"])
        assert(setup["schema_version"] == nil && setup["import_summary"] == nil && setup["saved_step"] == nil)
        assert(payload["expected_revision"] as? Int == 4)
        try await onboarding.submit()
        let submit = await transport.captured().last!
        let submitBody = try JSONSerialization.jsonObject(with: submit.httpBody!) as! [String: Any]
        assert(submitBody["expected_revision"] as? Int == 5)
        print("Auth and live onboarding checks passed")
    }
}
