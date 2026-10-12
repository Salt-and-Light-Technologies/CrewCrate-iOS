import Foundation
import Observation

@MainActor
@Observable
final class BusinessProfileEditorModel {
    var fields = BusinessProfileFields()
    var isBusy = false
    var hasLoaded = false
    var error: String?
    var savedNotice = false
    private var original: BusinessProfileRecord?
    let business: BusinessSummary
    private let service: any BusinessProfileServicing
    init(business: BusinessSummary, service: any BusinessProfileServicing) {
        self.business = business; self.service = service
    }
    var hasEdits: Bool { original != nil && fields != original?.onboarding }
    var canSave: Bool {
        hasLoaded && !isBusy && !fields.business_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        fields.business_name.count <= 160 && fields.services.count <= 10000 && fields.ai_boundaries.count <= 10000
    }
    func load() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let record = try await service.businessProfile(id: business.id)
            original = record; fields = record.onboarding; hasLoaded = true; error = nil
        } catch { self.error = error.localizedDescription }
    }
    func save() async {
        guard canSave, let original else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            let saved = try await service.saveBusinessProfile(id: business.id, revision: original.revision, fields: fields)
            self.original = saved; fields = saved.onboarding; savedNotice = true
        } catch { self.error = error.localizedDescription }
    }
}
