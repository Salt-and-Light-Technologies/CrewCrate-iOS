import Foundation
import Observation

@MainActor @Observable
final class PartnerReviewViewModel {
    private(set) var partner: PartnerWorkspace?
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private(set) var notice: String?
    var decisionNote = ""
    @ObservationIgnored private let id: UUID
    @ObservationIgnored private let repository: any PartnerRepository
    init(id: UUID, repository: any PartnerRepository) { self.id = id; self.repository = repository }
    func load() async {
        guard !isBusy else { return }
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do { partner = try await repository.partner(id: id) }
        catch { errorMessage = error.localizedDescription }
    }
    func decide(_ action: ReviewAction) async {
        guard !isBusy, let current = partner else { return }
        isBusy = true; errorMessage = nil; notice = nil
        defer { isBusy = false }
        do {
            partner = try await repository.decide(id: id, expectedRevision: current.revision, action: action, reason: decisionNote)
            decisionNote = ""
            notice = "\(action.rawValue) in this demo. No partner was notified and no campaign was activated."
        } catch { errorMessage = error.localizedDescription }
    }
}
