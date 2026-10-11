import Foundation

@main struct OwnerReviewChecks {
    @MainActor static func main() async throws {
        let fixtures = DemoPartnerFixtures.make()
        let repository = DemoPartnerRepository(partners: fixtures)
        let ready = fixtures[0], blocked = fixtures[1], draft = fixtures[2]
        func check(_ value: Bool, _ label: String) { precondition(value, label) }
        check(ready.canApprove && !blocked.canApprove, "Readiness gates")
        do { _ = try await repository.decide(id: blocked.id, expectedRevision: 0, action: .approve, reason: ""); fatalError("Missing launch requirements accepted") }
        catch PartnerRepositoryError.missingRequirements {}
        do { _ = try await repository.decide(id: draft.id, expectedRevision: 0, action: .approve, reason: ""); fatalError("Draft approved") }
        catch PartnerRepositoryError.invalidTransition {}
        do { _ = try await repository.decide(id: blocked.id, expectedRevision: 0, action: .requestChanges, reason: "  "); fatalError("Empty reason accepted") }
        catch PartnerRepositoryError.reasonRequired {}
        let approved = try await repository.decide(id: ready.id, expectedRevision: 0, action: .approve, reason: "Reviewed sample setup")
        check(approved.status == .pilotApproved && approved.revision == 1 && approved.history.count == 1, "Approval and revision")
        check(approved.history[0].previousStatus == .submitted && approved.history[0].resultingStatus == .pilotApproved, "History transitions")
        do { _ = try await repository.decide(id: ready.id, expectedRevision: 0, action: .pause, reason: "Stale review"); fatalError("Stale revision accepted") }
        catch PartnerRepositoryError.conflict {}
        let paused = try await repository.decide(id: ready.id, expectedRevision: 1, action: .pause, reason: "  Review reporting  ")
        check(paused.status == .paused && paused.history.last?.reason == "Review reporting", "Pause and trimmed reason")
        let resumed = try await repository.decide(id: ready.id, expectedRevision: 2, action: .resume, reason: "")
        check(resumed.status == .pilotApproved && resumed.pausedFrom == nil && resumed.history.count == 3, "Resume previous status")
        let dashboard = OwnerDashboardViewModel(repository: repository)
        await dashboard.load()
        check(dashboard.partners.count == 3 && dashboard.approvedCount == 1 && dashboard.awaitingReviewCount == 1, "Dashboard counts")
        dashboard.search = " DENTAL "
        check(dashboard.filteredPartners.count == 1, "Industry search")
        dashboard.statusFilter = .pilotApproved
        check(dashboard.filteredPartners.isEmpty, "Combined filters")
        let review = dashboard.makeReviewViewModel(id: blocked.id)
        await review.load()
        await review.decide(.approve)
        check(review.errorMessage != nil && review.partner?.revision == 0 && !review.isBusy, "Rejected decision preserves state")
        review.decisionNote = "Please supply reporting evidence"
        await review.decide(.requestChanges)
        check(review.partner?.status == .changesRequested && review.notice != nil && review.decisionNote.isEmpty, "View model decision")
        let missing = dashboard.makeReviewViewModel(id: UUID())
        await missing.load()
        check(missing.errorMessage != nil && missing.partner == nil, "Missing record recovery")
        print("Owner review checks passed: readiness, transitions, history, revisions, filtering and error recovery.")
    }
}
