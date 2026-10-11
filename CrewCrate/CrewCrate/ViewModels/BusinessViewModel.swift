import Foundation
import Observation

@MainActor
@Observable
final class BusinessViewModel {
    var workspaces: [BusinessWorkspace] = []
    var selectedID: UUID?
    var details = BusinessDetails()
    var isBusy = false
    var hasLoaded = false
    var error: String?
    var saved = false
    let service: any BusinessServicing
    init(service: any BusinessServicing) { self.service = service }
    var canSave: Bool { hasLoaded && !isBusy && !details.business_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func select(_ id: UUID?) {
        selectedID = id
        details = workspaces.first(where: { $0.id == id })?.onboarding ?? BusinessDetails()
        saved = false
    }
    func load() async {
        guard !isBusy else { return }
        isBusy = true; error = nil
        defer { isBusy = false }
        do {
            workspaces = try await service.businesses()
            select(workspaces.first(where: { $0.id == selectedID })?.id ?? workspaces.first?.id)
            hasLoaded = true
        } catch { self.error = error.localizedDescription }
    }
    func save() async -> Bool {
        guard canSave else { return false }
        isBusy = true; error = nil; saved = false
        defer { isBusy = false }
        do {
            details.business_name = details.business_name.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = try await service.saveBusiness(id: selectedID, revision: workspaces.first(where: { $0.id == selectedID })?.revision, details: details)
            if let index = workspaces.firstIndex(where: { $0.id == value.id }) { workspaces[index] = value }
            else { workspaces.append(value) }
            selectedID = value.id; details = value.onboarding; saved = true
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
}
