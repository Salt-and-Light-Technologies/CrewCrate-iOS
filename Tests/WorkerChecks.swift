import Foundation

private actor WorkerFake: WorkerServicing {
    let business = UUID()
    let conversation = UUID()
    var alerts: [WorkerAlert] = []
    var accepted = false
    var savedRevision: Int?
    var failRead = false
    func team(_ business: UUID) async throws -> WorkerTeam { WorkerTeam(members: [], invitations: []) }
    func inviteWorker(_ business: UUID, email: String) async throws -> WorkerInvitation {
        WorkerInvitation(id: UUID(), email: email, expires_at: "2026-10-19T12:00:00Z", status: "pending", token: "test-code")
    }
    func revokeInvitation(_ business: UUID, invitation: UUID) async throws { }
    func removeWorker(_ business: UUID, worker: UUID) async throws { }
    func acceptWorkerInvitation(token: String, name: String) async throws { accepted = token == "test-code" && name == "Alex" }
    func incomingLeads(_ business: UUID) async throws -> [IncomingLead] { [try await incomingLead(business, conversation: conversation)] }
    func incomingLead(_ business: UUID, conversation: UUID) async throws -> IncomingLead {
        IncomingLead(id: conversation, name: "Pat", phone: "15551234567", email: "", status: "handoff", revision: 4,
            source: "manual_tracking", events: [FollowUpEvent(revision: 4, note: "Requested information", status: "handoff")])
    }
    func saveFollowUp(_ business: UUID, lead: IncomingLead, note: String, status: String) async throws { savedRevision = lead.revision }
    func workerAlerts() async throws -> [WorkerAlert] { alerts }
    func readWorkerAlert(_ id: UUID) async throws {
        alerts = alerts.map { WorkerAlert(id: $0.id, partner_id: $0.partner_id, conversation_id: $0.conversation_id,
            read: $0.id == id ? true : $0.read, title: $0.title) }
    }
    func registerWorkerDevice(token: String, environment: String) async throws { }
    func unregisterWorkerDevice(token: String) async throws { }
    func addAlert() {
        alerts.insert(WorkerAlert(id: UUID(), partner_id: business, conversation_id: conversation, read: false,
            title: "A lead needs follow-up"), at: 0)
    }
}

private actor WorkerAuthFake: AuthenticationServicing {
    var ordinarySignup = false
    func restore() async throws -> Bool { false }
    func signIn(email: String, password: String) async throws { }
    func signUp(email: String, password: String) async throws -> Bool { ordinarySignup = true; return false }
    func recover(email: String) async throws { }
    func updatePassword(_ password: String) async throws { }
    func acceptCallback(_ url: URL) async throws -> Bool { false }
    func identity() async throws -> AuthenticatedIdentity { AuthenticatedIdentity(userID: UUID(), isOwner: false) }
    func signOut() async throws { }
}

private actor WorkerBusinessFake: BusinessApplicationServicing {
    func application() async throws -> BusinessApplication? {
        BusinessApplication(id: UUID(), business_name: "Old request", contact_name: "Alex", email: "alex@example.com",
            phone: "15551234567", referral: "", status: "pending", revision: 0, partner_id: nil, review_note: "")
    }
    func submitApplication(_ draft: BusinessApplicationDraft) async throws -> BusinessApplication { fatalError() }
    func pendingApplications() async throws -> [BusinessApplication] { [] }
    func decide(_ application: BusinessApplication, approve: Bool, note: String) async throws -> BusinessApplication { fatalError() }
    func businesses() async throws -> [BusinessSummary] {
        [BusinessSummary(id: UUID(), name: "Team", status: "draft", revision: 0, access_approved: true, member_role: "worker")]
    }
}

@main struct WorkerChecks {
    @MainActor static func main() async throws {
        let authService = WorkerAuthFake()
        let auth = AuthenticationViewModel(service: authService)
        auth.email = "alex@example.com"; auth.password = "password123"; auth.confirmPassword = "password123"
        await auth.createWorkerAccount()
        let ordinary = await authService.ordinarySignup
        precondition(ordinary && auth.signupComplete && auth.signupNeedsEmailConfirmation && auth.identity == nil)
        let access = BusinessAccessViewModel(isOwner: false, service: WorkerBusinessFake())
        await access.load()
        precondition(access.businesses.first?.member_role == "worker")
        let service = WorkerFake()
        let business = service.business
        let conversation = service.conversation
        let team = WorkerTeamModel(service: service)
        team.name = "Alex"; team.token = " test-code "
        let joined = await team.accept()
        precondition(joined)
        let accepted = await service.accepted
        precondition(accepted)
        let inbox = WorkerInboxModel(service: service)
        await service.addAlert()
        await inbox.load(business)
        precondition(inbox.unread == 1 && inbox.banner == nil && inbox.leads.count == 1)
        await service.addAlert()
        await inbox.load(business)
        precondition(inbox.unread == 2 && inbox.banner != nil)
        let opened = await inbox.open(business, conversation: conversation)
        precondition(opened && inbox.unread == 0 && inbox.banner == nil)
        await inbox.save(business, note: "Called back", status: "handoff")
        let revision = await service.savedRevision
        precondition(revision == 4)
        print("Worker signup, acceptance, landing access, alerts, read state and follow-up checks passed.")
    }
}
