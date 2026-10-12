import Foundation

private actor SignupFake: AuthenticationServicing {
    var signupCalls = 0
    var business: BusinessApplicationDraft?
    func restore() async throws -> Bool { false }
    func signIn(email: String, password: String) async throws { }
    func signUp(email: String, password: String) async throws -> Bool { preconditionFailure("Business details are required") }
    func signUp(email: String, password: String, business: BusinessApplicationDraft) async throws -> Bool {
        signupCalls += 1; self.business = business; return false
    }
    func recover(email: String) async throws { }
    func updatePassword(_ password: String) async throws { }
    func acceptCallback(_ url: URL) async throws -> Bool { false }
    func identity() async throws -> AuthenticatedIdentity { AuthenticatedIdentity(userID: UUID(), isOwner: false) }
    func signOut() async throws { }
}

nonisolated private struct SignupStore: AuthSessionStore {
    let session: AuthSession
    func load() throws -> AuthSession? { session }
    func save(_ session: AuthSession) throws { }
    func clear() throws { }
}
private actor SignupTransport: LeadHTTPTransport {
    var replies: [Data]
    var requests: [URLRequest] = []
    init(replies: [Data]) { self.replies = replies }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        precondition(!replies.isEmpty)
        return (replies.removeFirst(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@main
struct SignupChecks {
    @MainActor static func main() async throws {
        let fake = SignupFake()
        let model = AuthenticationViewModel(service: fake)
        model.email = "  sam@example.com  "
        model.password = "test-password"
        model.confirmPassword = "test-password"
        precondition(model.validateAccountDetails())
        let before = await fake.signupCalls
        precondition(before == 0) // Continue validates locally and never creates an account.
        await model.createAccount()
        let incompleteCalls = await fake.signupCalls
        precondition(incompleteCalls == 0 && model.notice != nil)
        model.signupBusiness = BusinessApplicationDraft(business_name: "Sam's Roofing", contact_name: "Sam",
            email: "", phone: "+13125550123", referral: "Joe")
        await model.createAccount()
        let completeCalls = await fake.signupCalls
        let business = await fake.business
        precondition(completeCalls == 1 && business?.email == "sam@example.com")
        precondition(model.signupComplete && model.signupNeedsEmailConfirmation && model.password.isEmpty)

        let draft = business!
        let signupTransport = SignupTransport(replies: [Data("{}".utf8)])
        let auth = SupabaseSession(transport: signupTransport)
        let signedIn = try await auth.signUp(email: "sam@example.com", password: "test-password", business: draft)
        precondition(!signedIn)
        let signupRequest = await signupTransport.requests[0]
        let signupJSON = try JSONSerialization.jsonObject(with: signupRequest.httpBody!) as! [String: Any]
        precondition(signupJSON["email"] as? String == "sam@example.com")
        precondition(signupJSON["password"] as? String == "test-password")
        let metadata = signupJSON["data"] as! [String: String]
        let restoredDraft = try JSONDecoder().decode(BusinessApplicationDraft.self,
            from: Data(metadata["crewcrate_business_application"]!.utf8))
        precondition(restoredDraft.business_name == draft.business_name && restoredDraft.referral == "Joe")
        precondition(metadata["password"] == nil && metadata["is_owner"] == nil)

        let application = BusinessApplication(id: UUID(), business_name: draft.business_name, contact_name: draft.contact_name,
            email: draft.email, phone: draft.phone, referral: draft.referral, status: "pending", revision: 0,
            partner_id: nil, review_note: "")
        let userJSON = try JSONSerialization.data(withJSONObject: ["user_metadata": metadata])
        let recoveryTransport = SignupTransport(replies: [Data("null".utf8), Data("[]".utf8), userJSON, try JSONEncoder().encode(application)])
        let recovery = SupabaseSession(store: SignupStore(session: AuthSession(accessToken: "test-token",
            refreshToken: "test-refresh", expiresAt: Date().addingTimeInterval(3600), userID: UUID())), transport: recoveryTransport)
        _ = try await recovery.restore()
        let pending = try await recovery.application()
        precondition(pending?.business_name == draft.business_name && pending?.status == "pending")
        let requests = await recoveryTransport.requests
        precondition(requests.count == 4 && requests[3].httpMethod == "POST")
        precondition(requests[3].value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        let body = try JSONDecoder().decode(BusinessApplicationDraft.self, from: requests[3].httpBody!)
        precondition(body.phone == draft.phone && body.referral == "Joe")
        print("Two-step signup, metadata persistence and verified application recovery checks passed.")
    }
}
