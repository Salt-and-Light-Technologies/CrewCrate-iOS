import Foundation
import Observation
@MainActor @Observable
final class SalesHandoffViewModel: Identifiable {
    let id: UUID
    let partnerName: String
    var newEmail = ""
    private(set) var emails: [String] = []
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    @ObservationIgnored private let repository: any SalesHandoffRepository
    init(partnerID: UUID, partnerName: String, repository: any SalesHandoffRepository) { id = partnerID; self.partnerName = partnerName; self.repository = repository }
    func load() async {
        guard !isBusy else { return }; isBusy = true; defer { isBusy = false }
        do { emails = try await repository.handoffEmails(partnerID: id); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
    func add() async {
        guard !isBusy else { return }
        let value = newEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard OnboardingValidation.email(value), value.count <= 320 else { errorMessage = "Enter a valid sales handoff email."; return }
        isBusy = true; defer { isBusy = false }
        do { emails = try await repository.addHandoffEmail(partnerID: id, email: value); newEmail = ""; errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
}
