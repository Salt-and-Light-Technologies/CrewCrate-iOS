import Foundation
import Observation

@MainActor @Observable
final class LeadWorkspaceViewModel: Identifiable {
    private(set) var workspace: LeadWorkspaceSummary?
    private(set) var leads: [LeadRecord] = []
    private(set) var batches: [LeadImportBatch] = []
    private(set) var events: [LeadActivity] = []
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private(set) var notice: String?
    private(set) var document: CSVDocument?
    private(set) var requiresColumnMapping = false
    private(set) var preview: LeadImportPreview?
    var mapping = LeadColumnMapping() { didSet { preview = nil; notice = nil } }
    var search = ""
    var statusFilter: LeadStatus?
    private(set) var hasMoreLeads = false
    private(set) var hasMoreImports = false
    private(set) var hasMoreActivity = false
    let isDemo: Bool
    @ObservationIgnored let id: UUID
    @ObservationIgnored private let repository: any LeadRepository
    @ObservationIgnored private let inspector: any LeadFileInspecting
    @ObservationIgnored private var loadedSearch = ""
    @ObservationIgnored private var loadedStatus: LeadStatus?
    init(id: UUID, repository: any LeadRepository, isDemo: Bool = true, inspector: any LeadFileInspecting = LeadFileInspector()) {
        self.id = id; self.repository = repository; self.isDemo = isDemo; self.inspector = inspector
    }
    func load() async {
        guard !isBusy else { return }
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            let query = search, status = statusFilter
            let summary = try await repository.workspace(id: id)
            let records = try await repository.leads(partnerID: id, search: query, status: status, offset: 0)
            let imports = try await repository.imports(partnerID: id, offset: 0)
            let activity = try await repository.activity(partnerID: id, offset: 0)
            workspace = summary; leads = records; batches = imports; events = activity
            loadedSearch = query; loadedStatus = status
            hasMoreLeads = records.count == 50; hasMoreImports = imports.count == 50; hasMoreActivity = activity.count == 50
        } catch { errorMessage = error.localizedDescription }
    }
    func loadMore(_ section: String) async {
        guard !isBusy else { return }
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            switch section {
            case "leads":
                let next = try await repository.leads(partnerID: id, search: loadedSearch, status: loadedStatus, offset: leads.count)
                let known = Set(leads.map(\.id)); leads += next.filter { !known.contains($0.id) }; hasMoreLeads = next.count == 50
            case "imports":
                let next = try await repository.imports(partnerID: id, offset: batches.count)
                let known = Set(batches.map(\.id)); batches += next.filter { !known.contains($0.id) }; hasMoreImports = next.count == 50
            default:
                let next = try await repository.activity(partnerID: id, offset: events.count)
                let known = Set(events.map(\.id)); events += next.filter { !known.contains($0.id) }; hasMoreActivity = next.count == 50
            }
        } catch { errorMessage = error.localizedDescription }
    }
    func inspect(_ url: URL) async {
        guard !isBusy else { return }
        isBusy = true; errorMessage = nil; preview = nil
        defer { isBusy = false }
        do { try setDocument(await inspector.inspect(url)) }
        catch { document = nil; errorMessage = error.localizedDescription }
    }
    func uploadSelectedFile(_ url: URL) async {
        await inspect(url)
        guard let document else { return }
        let phones = document.headers.indices.filter {
            let name = document.headers[$0].lowercased()
            return name.contains("phone") || name.contains("mobile")
        }
        guard phones.count == 1 else { requiresColumnMapping = true; return }
        requiresColumnMapping = false
        mapping.phone = phones[0]
        await previewImport()
        guard preview != nil else { return }
        await commitImport()
    }
    private func setDocument(_ value: CSVDocument) throws {
        document = value
        mapping = LeadColumnMapping(phone: value.headers.firstIndex(where: { $0.lowercased().contains("phone") }) ?? 0,
            name: value.headers.firstIndex(where: { $0.lowercased() == "name" }), email: value.headers.firstIndex(where: { $0.lowercased().contains("email") }))
    }
    func useSampleFile() {
        guard isDemo, !isBusy else { return }
        do { try setDocument(CSVParser.parse(data: Data("Name,Phone,Email\nSample person,+1 (202) 555-0101,sample@example.com\nDuplicate,+12025550101,duplicate@example.com\nInvalid,abc,bad\nSecond sample,+12025550102,second@example.com\n".utf8), fileName: "sample-leads.csv")); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
    func previewImport() async {
        guard !isBusy, let document else { return }
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do { preview = try await repository.preview(partnerID: id, document: document, mapping: mapping) }
        catch { preview = nil; errorMessage = error.localizedDescription }
    }
    func commitImport() async {
        guard !isBusy, let document, let preview else { return }
        isBusy = true; errorMessage = nil
        do {
            let batch = try await repository.importLeads(partnerID: id, document: document, mapping: mapping, expectedRevision: preview.partnerRevision)
            self.document = nil; self.preview = nil
            notice = "\(batch.imported) contacts imported. No messages were sent."
        } catch { errorMessage = error.localizedDescription; self.preview = nil }
        isBusy = false
        if self.document == nil { await load() }
    }
    func classify(_ lead: LeadRecord, as status: LeadStatus) async {
        guard !isBusy else { return }
        isBusy = true; errorMessage = nil
        var succeeded = false
        do { _ = try await repository.classify(partnerID: id, leadID: lead.id, status: status, expectedRevision: lead.revision); succeeded = true }
        catch { errorMessage = error.localizedDescription }
        isBusy = false
        if succeeded { await load() }
    }
    func setPermission(_ lead: LeadRecord, permission: String, evidence: String) async {
        guard !isBusy else { return }; isBusy = true; errorMessage = nil
        var succeeded = false
        do { _ = try await repository.setPermission(partnerID: id, leadID: lead.id, permission: permission, evidence: evidence, expectedRevision: lead.revision); succeeded = true } catch { errorMessage = error.localizedDescription }
        isBusy = false
        if succeeded { await load() }
    }
    func cancelImport() { document = nil; preview = nil; requiresColumnMapping = false }
    func reportError(_ error: Error) {
        let value = error as NSError
        if error is CancellationError || (value.domain == NSCocoaErrorDomain && value.code == NSUserCancelledError) || (value.domain == NSURLErrorDomain && value.code == NSURLErrorCancelled) { return }
        errorMessage = error.localizedDescription
    }
    func clearImportError() { errorMessage = nil }

}
