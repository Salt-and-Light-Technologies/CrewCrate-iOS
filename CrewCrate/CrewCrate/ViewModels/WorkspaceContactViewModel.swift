import Foundation
import Observation

@MainActor
@Observable
final class WorkspaceContactViewModel {
    var contacts: [WorkspaceContact] = []
    var search = ""
    var isBusy = false
    var hasLoaded = false
    var hasMore = false
    var error: String?
    private var appliedSearch = ""
    private var nextOffset = 0
    let business: UUID
    let campaign: UUID
    let service: any WorkspaceContactServicing
    init(business: UUID, campaign: UUID, service: any WorkspaceContactServicing) {
        self.business = business; self.campaign = campaign; self.service = service
    }
    func load(reset: Bool = true) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let query = reset ? search : appliedSearch
        do {
            let page = try await service.contacts(business: business, campaign: campaign, search: query,
                offset: reset ? 0 : nextOffset)
            if reset { contacts = page; appliedSearch = query }
            else { contacts.append(contentsOf: page.filter { new in !contacts.contains(where: { $0.id == new.id }) }) }
            nextOffset = reset ? page.count : nextOffset + page.count
            hasMore = page.count == 250
            hasLoaded = true; error = nil
        } catch { self.error = error.localizedDescription }
    }
    func replace(_ contact: WorkspaceContact) {
        if let index = contacts.firstIndex(where: { $0.id == contact.id }) { contacts[index] = contact }
    }
}

@MainActor
@Observable
final class ContactPermissionEditorModel {
    var fields = ContactReviewFields()
    var date = Date()
    var isBusy = false
    var error: String?
    let contact: WorkspaceContact
    let business: UUID
    private let service: any WorkspaceContactServicing
    init(contact: WorkspaceContact, business: UUID, service: any WorkspaceContactServicing) {
        self.contact = contact; self.business = business; self.service = service
        if contact.opted_out || contact.sms_permission == "revoked" { fields.action = "exclude" }
    }
    var canSave: Bool {
        guard !isBusy, fields.evidence.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8,
              fields.evidence.count <= 1400 else { return false }
        if fields.action != "record_permission" { return true }
        return !contact.opted_out && contact.sms_permission != "revoked" && fields.attested &&
            !fields.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            fields.country.count == 2 && fields.country.allSatisfy { $0.isASCII && $0.isLetter }
    }
    var hasEdits: Bool {
        let defaultAction = contact.opted_out || contact.sms_permission == "revoked" ? "exclude" : "record_permission"
        return !fields.evidence.isEmpty || !fields.source.isEmpty || fields.attested || fields.country != "US" ||
            fields.action != defaultAction || !Calendar.current.isDateInToday(date)
    }
    func save() async -> WorkspaceContact? {
        guard canSave else { return nil }
        isBusy = true
        defer { isBusy = false }
        var submission = fields
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        submission.consent_date = formatter.string(from: date)
        do { return try await service.reviewContact(business: business, contact: contact, fields: submission) }
        catch { self.error = error.localizedDescription; return nil }
    }
}
