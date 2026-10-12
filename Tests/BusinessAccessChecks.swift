import Foundation

private actor AuthenticationFake: AuthenticationServicing {
    let owner: Bool
    var signedOut = false
    init(owner: Bool) { self.owner = owner }
    func restore() async throws -> Bool { false }
    func signIn(email: String, password: String) async throws { }
    func signUp(email: String, password: String) async throws -> Bool { false }
    func recover(email: String) async throws { }
    func updatePassword(_ password: String) async throws { }
    func acceptCallback(_ url: URL) async throws -> Bool { false }
    func identity() async throws -> AuthenticatedIdentity { AuthenticatedIdentity(userID: UUID(), isOwner: owner) }
    func signOut() async throws { signedOut = true }
}

private actor ApplicationServiceFake: BusinessApplicationServicing {
    var current: BusinessApplication?
    var rows: [BusinessSummary] = []
    var pending: [BusinessApplication] = []
    var failDecision = false

    func application() async throws -> BusinessApplication? { current }
    func businesses() async throws -> [BusinessSummary] { rows }
    func pendingApplications() async throws -> [BusinessApplication] { pending }
    func submitApplication(_ draft: BusinessApplicationDraft) async throws -> BusinessApplication {
        let result = makeApplication(draft: draft)
        current = result
        pending = [result]
        return result
    }
    func decide(_ application: BusinessApplication, approve: Bool, note: String) async throws -> BusinessApplication {
        if failDecision { throw AuthenticationFailure(message: "Record changed; refresh before reviewing") }
        if approve { rows = [BusinessSummary(id: UUID(), name: application.business_name, status: "draft", revision: 1, access_approved: true)] }
        pending = []
        let reviewed = BusinessApplication(id: application.id, business_name: application.business_name,
            contact_name: application.contact_name, email: application.email, phone: application.phone,
            referral: application.referral, status: approve ? "approved" : "denied", revision: 1,
            partner_id: rows.first?.id, review_note: note)
        current = reviewed
        return reviewed
    }
    func setFailure() { failDecision = true }
    func addUnapprovedMembership() {
        rows = [BusinessSummary(id: UUID(), name: "Legacy business", status: "draft", revision: 0)]
    }
    func addApprovedLookingMembership() {
        rows = [BusinessSummary(id: UUID(), name: "Legacy business", status: "draft", revision: 0, access_approved: true)]
    }
}

nonisolated private func makeApplication(draft: BusinessApplicationDraft) -> BusinessApplication {
    BusinessApplication(id: UUID(), business_name: draft.business_name, contact_name: draft.contact_name,
        email: draft.email, phone: draft.phone, referral: draft.referral, status: "pending", revision: 0,
        partner_id: nil, review_note: "")
}

@main
struct BusinessAccessChecks {
    @MainActor static func main() async throws {
        let service = ApplicationServiceFake()
        let applicant = BusinessAccessViewModel(isOwner: false, service: service)
        await applicant.load()
        precondition(applicant.hasLoaded && applicant.application == nil && applicant.businesses.isEmpty)
        await service.addUnapprovedMembership()
        await applicant.load()
        precondition(applicant.businesses.isEmpty) // membership without explicit approval cannot open a workspace
        applicant.draft = BusinessApplicationDraft(business_name: "Bob's Roofing", contact_name: "Bob",
            email: "bob@example.com", phone: "+13125550123", referral: "Joe")
        precondition(applicant.draft.isComplete)
        await applicant.submit()
        precondition(applicant.application?.status == "pending" && applicant.businesses.isEmpty)
        await service.addApprovedLookingMembership()
        await applicant.load()
        precondition(applicant.application?.status == "pending" && applicant.businesses.isEmpty)
        let owner = BusinessAccessViewModel(isOwner: true, service: service)
        await owner.load()
        precondition(owner.requests.count == 1)
        let approved = await owner.decide(owner.requests[0], approve: true, note: "")
        precondition(approved && owner.requests.isEmpty && owner.businesses.count == 1)
        await applicant.load()
        precondition(applicant.application?.status == "approved" && applicant.businesses.count == 1)
        await service.setFailure()
        let request = makeApplication(draft: applicant.draft)
        owner.requests = [request]
        let failed = await owner.decide(request, approve: false, note: "Contact us")
        precondition(!failed && owner.requests.count == 1 && owner.error != nil && !owner.isBusy)
        var invalid = applicant.draft
        invalid.email = "invalid"
        precondition(!invalid.isComplete)
        let ordinaryService = AuthenticationFake(owner: false)
        let ordinaryLogin = AuthenticationViewModel(service: ordinaryService)
        ordinaryLogin.email = "worker@example.com"
        ordinaryLogin.password = "password"
        ordinaryLogin.signingInAsOwner = true
        await ordinaryLogin.login()
        precondition(ordinaryLogin.identity == nil && ordinaryLogin.notice != nil)
        let wasSignedOut = await ordinaryService.signedOut
        precondition(wasSignedOut)
        let ownerLogin = AuthenticationViewModel(service: AuthenticationFake(owner: true))
        ownerLogin.email = "owner@example.com"
        ownerLogin.password = "password"
        ownerLogin.signingInAsOwner = true
        await ownerLogin.login()
        precondition(ownerLogin.identity?.isOwner == true)
        print("Business application state checks passed.")
    }
}
