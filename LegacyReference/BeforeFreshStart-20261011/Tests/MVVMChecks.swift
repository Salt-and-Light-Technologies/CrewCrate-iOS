import Foundation

actor FakeSetupRepository: PartnerSetupRepository {
    let id = UUID()
    var status = "draft"
    var empty = false
    func setupPartners() async throws -> [LivePartner] {
        if empty { return [] }
        return [LivePartner(id: id, name: "Test partner", status: status, revision: 0)]
    }
    func setStatus(_ value: String) { status = value }
    func clear() { empty = true }
}
actor FakeSubmissionStore: ReviewSubmittingStore {
    let repository: FakeSetupRepository
    var saved: OnboardingDraft
    var shouldFail = false
    init(repository: FakeSetupRepository) {
        self.repository = repository
        var draft = DemoPartnerFixtures.make()[0].onboarding
        draft.preparedAt = nil
        saved = draft
    }
    func load() async throws -> OnboardingDraft? { saved }
    func save(_ draft: OnboardingDraft) async throws { saved = draft }
    func submit() async throws {
        if shouldFail { throw LeadAPIError.conflict }
        await repository.setStatus("submitted")
    }
    func fail() { shouldFail = true }
}
actor FakeAuth: SessionServicing {
    private var signedIn = false
    func restore() async throws -> Bool { signedIn }
    func signIn(email: String, password: String) async throws { signedIn = true }
    func signOut() async throws { signedIn = false }
    func accessToken() async throws -> String { "fake-token" }
}
@main struct MVVMChecks {
    @MainActor static func main() async throws {
        let repository = FakeSetupRepository()
        let submission = FakeSubmissionStore(repository: repository)
        let analytics = PartnerHomeViewModel(repository: CampaignAnalyticsService(campaigns: DemoPartnerRepository()))
        let flow = PartnerExperienceViewModel(repository: repository, analytics: analytics, isOwner: false,
            makeOnboarding: { _, completed in OnboardingViewModel(store: submission, isLive: true, onSubmitted: completed) })
        await flow.load()
        guard let onboarding = flow.onboarding else { fatalError("Draft partner bypassed onboarding") }
        await onboarding.load()
        await onboarding.prepareReview()
        assert(onboarding.isPrepared && flow.onboarding == nil)
        await flow.load()
        assert(flow.onboarding == nil && flow.errorMessage == nil)
        await repository.setStatus("changes_requested")
        await submission.fail()
        await flow.load()
        guard let editing = flow.onboarding else { fatalError("Changes request bypassed onboarding") }
        await editing.load(); editing.resumeEditing(); editing.draft.confirmsAccuracy = true
        await editing.prepareReview()
        assert(!editing.isPrepared && flow.onboarding != nil && editing.errorMessage != nil)
        await repository.clear(); await flow.load()
        assert(flow.errorMessage != nil)
        let ownerFlow = PartnerExperienceViewModel(repository: repository, analytics: analytics, isOwner: true,
            makeOnboarding: { _, completed in OnboardingViewModel(store: submission, isLive: true, onSubmitted: completed) })
        await ownerFlow.load(); assert(ownerFlow.onboarding == nil && ownerFlow.errorMessage == nil)
        let auth = FakeAuth()
        let identity = LiveIdentity(user_id: UUID(), is_owner: false)
        let session = SessionViewModel(auth: auth, loadIdentity: { identity }, makeExperience: { _ in flow })
        await session.restore(); assert(!session.isRestoring && session.identity == nil)
        session.email = "test@example.com"; session.password = "test-password"
        await session.signIn()
        assert(session.identity?.user_id == identity.user_id && session.experience === flow && session.password.isEmpty)
        await session.signOut(); assert(session.identity == nil && session.experience == nil)
        let failing = SessionViewModel(auth: auth, loadIdentity: { throw LeadAPIError.forbidden }, makeExperience: { _ in flow })
        await failing.restore(); failing.email = "test@example.com"; failing.password = "test-password"
        await failing.signIn()
        assert(failing.identity == nil && failing.experience == nil && failing.errorMessage != nil)
        print("MVVM checks passed: injected auth, role lookup failure, sign-out isolation, successful submission routing, failed submission gating and returning partner routing")
    }
}
