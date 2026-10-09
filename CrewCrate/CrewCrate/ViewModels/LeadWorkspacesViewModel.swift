import Foundation
import Observation

@MainActor @Observable
final class LeadWorkspacesViewModel {
    private(set) var workspaces: [LeadWorkspaceSummary] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    let isDemo: Bool
    @ObservationIgnored private let repository: any LeadRepository
    init(repository: any LeadRepository, isDemo: Bool = true) { self.repository = repository; self.isDemo = isDemo }
    func load() async {
        guard !isLoading else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do { workspaces = try await repository.workspaces() }
        catch { errorMessage = error.localizedDescription }
    }
    func detail(id: UUID) -> LeadWorkspaceViewModel { LeadWorkspaceViewModel(id: id, repository: repository, isDemo: isDemo) }
}
