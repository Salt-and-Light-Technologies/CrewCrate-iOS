import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

nonisolated struct TestToken: APITokenProvider { func accessToken() async throws -> String { "test-token" } }
actor FakeLeadHTTP: LeadHTTPTransport {
    var requests: [URLRequest] = []
    var status = 200
    var data = Data()
    func respond(_ text: String, status: Int = 200) { self.data = Data(text.utf8); self.status = status }
    func last() -> URLRequest? { requests.last }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

nonisolated struct AccountUploadInspector: LeadFileInspecting {
    let document: CSVDocument
    func inspect(_ url: URL) async throws -> CSVDocument { document }
}

@main struct LeadWorkspaceChecks {
    @MainActor static func main() async throws {
        func check(_ value: Bool, _ label: String) { precondition(value, label) }
        var fixtures = DemoPartnerFixtures.make(); fixtures[1].status = .draft
        let repo = DemoPartnerRepository(partners: fixtures)
        let id = fixtures[2].id
        let csv = try CSVParser.parse(data: Data("Name,Phone,Email\nFirst,+1 (202) 555-0101,first@example.com\nDuplicate,+12025550101,duplicate@example.com\nBad,abc,bad\nSecond,+12025550102,second@example.com\n".utf8), fileName: "check.csv")
        let mapping = LeadColumnMapping(phone: 1, name: 0, email: 2)
        let preview = try await repo.preview(partnerID: id, document: csv, mapping: mapping)
        check(preview.imported == 2 && preview.duplicates == 1 && preview.invalid == 1, "Preview totals")
        check(preview.issues.map(\.rowNumber) == [2,3], "Issue row numbers")
        let before = try await repo.workspace(id: id)
        check(before.totalLeads == 0 && before.revision == 0, "Preview read only")
        let batch = try await repo.importLeads(partnerID: id, document: csv, mapping: mapping, expectedRevision: 0)
        check(batch.imported == 2, "Committed contacts")
        let summary = try await repo.workspace(id: id)
        check(summary.totalLeads == 2 && summary.importCount == 1 && summary.revision == 1, "Workspace totals")
        let second = try await repo.preview(partnerID: id, document: csv, mapping: mapping)
        check(second.imported == 0 && second.duplicates == 3, "Across-batch duplicates")
        do { _ = try await repo.importLeads(partnerID: id, document: csv, mapping: mapping, expectedRevision: 0); fatalError("Stale import accepted") }
        catch LeadRepositoryError.conflict {}
        do { _ = try await repo.preview(partnerID: id, document: csv, mapping: LeadColumnMapping(phone: 1, name: 1)); fatalError("Duplicate mapping accepted") }
        catch LeadRepositoryError.invalidMapping {}
        let records = try await repo.leads(partnerID: id, search: "FIRST", status: nil, offset: 0)
        check(records.count == 1, "Case-insensitive search")
        let updated = try await repo.classify(partnerID: id, leadID: records[0].id, status: .eligible, expectedRevision: 0)
        check(updated.revision == 1 && updated.status == .eligible, "Classification")
        do { _ = try await repo.classify(partnerID: id, leadID: records[0].id, status: .excluded, expectedRevision: 0); fatalError("Stale classification accepted") }
        catch LeadRepositoryError.conflict {}
        do { _ = try await repo.classify(partnerID: fixtures[1].id, leadID: records[0].id, status: .excluded, expectedRevision: 1); fatalError("Cross-partner lead changed") }
        catch LeadRepositoryError.missing {}
        let events = try await repo.activity(partnerID: id, offset: 0)
        check(events.count == 2 && events[0].action == "Lead status changed", "Recorded activity")
        let owner = OwnerDashboardViewModel(repository: repo, leadRepository: repo)
        await owner.load()
        check(owner.makeLeadViewModel(id: id) != nil, "Owner workspace link")
        let current = try await repo.partner(id: id)
        _ = try await repo.decide(id: id, expectedRevision: current.revision, action: .pause, reason: "Review needed")
        do { _ = try await repo.classify(partnerID: id, leadID: records[0].id, status: .excluded, expectedRevision: 1); fatalError("Paused classification accepted") }
        catch LeadRepositoryError.locked {}
        let vm = LeadWorkspaceViewModel(id: fixtures[1].id, repository: repo)
        await vm.load(); vm.useSampleFile(); await vm.previewImport()
        check(vm.preview?.imported == 2, "View model preview")
        vm.mapping.email = nil
        check(vm.preview == nil, "Mapping invalidates preview")
        await vm.previewImport(); await vm.commitImport()
        check(vm.document == nil && vm.workspace?.totalLeads == 2 && vm.notice != nil, "View model import reload")

        let transport = FakeLeadHTTP()
        let api = try APILeadRepository(baseURL: URL(string: "https://crewcrate.example.com")!, tokens: TestToken(), ownerWorkspace: true, transport: transport)
        let json = """
        {"partner_id":"\(id)","name":"Any Industry","status":"changes_requested","partner_revision":7,"total_leads":2,"import_count":1,"lead_counts":{"eligible":1,"unreviewed":1}}
        """
        await transport.respond("[" + json + "]")
        let workspaces = try await api.workspaces()
        check(workspaces[0].status == .changesRequested && workspaces[0].counts[.eligible] == 1, "Summary wire mapping")
        let request = await transport.last()
        check(request?.url?.path == "/v1/owner/lead-workspaces" && request?.value(forHTTPHeaderField: "Authorization") == "Bearer test-token", "Authenticated owner route")
        await transport.respond("""
        {"partner_revision":7,"total_rows":4,"imported":2,"duplicates":1,"invalid":1,"issues":[{"row_number":3,"kind":"invalid","detail":"Check phone"}],"issues_truncated":false}
        """)
        let remotePreview = try await api.preview(partnerID: id, document: csv, mapping: mapping)
        check(remotePreview.partnerRevision == 7 && remotePreview.issues[0].rowNumber == 3, "Preview wire mapping")
        let multipart = await transport.last()
        let body = String(data: multipart!.httpBody!, encoding: .utf8)!
        check(multipart?.httpMethod == "POST" && multipart?.url?.path.hasSuffix("/imports/preview") == true && body.contains("name=\"phone_column\"\r\n\r\nPhone"), "Multipart mapping")
        await transport.respond("""
        [{"id":"\(records[0].id)","import_id":"\(batch.id)","name":"First","phone":"12025550101","email":"first@example.com","status":"eligible","revision":1}]
        """)
        let remoteLeads = try await api.leads(partnerID: id, search: "a&b", status: .eligible, offset: 50)
        check(remoteLeads[0].importID == batch.id, "Lead wire mapping")
        let filteredRequest = await transport.last()
        let query = URLComponents(url: filteredRequest!.url!, resolvingAgainstBaseURL: false)!.queryItems!
        check(query.contains(URLQueryItem(name: "search", value: "a&b")) && query.contains(URLQueryItem(name: "offset", value: "50")), "Escaped pagination and filters")
        await transport.respond("""
        [{"id":"\(batch.id)","file_name":"check.csv","total_rows":4,"imported":2,"duplicates":1,"invalid":1,"timestamp":"2026-10-08T18:30:00.123456Z"}]
        """)
        check(try await api.imports(partnerID: id, offset: 0).first?.imported == 2, "Fractional timestamps")
        await transport.respond("{}", status: 401)
        do { _ = try await api.workspace(id: id); fatalError("Unauthorized response accepted") }
        catch LeadAPIError.signIn {}
        await transport.respond("{}", status: 409)
        do { _ = try await api.classify(partnerID: id, leadID: records[0].id, status: .excluded, expectedRevision: 1); fatalError("Conflict accepted") }
        catch LeadAPIError.conflict {}
        let mutation = await transport.last()
        let object = try JSONSerialization.jsonObject(with: mutation!.httpBody!) as! [String: Any]
        check(object["expected_revision"] as? Int == 1 && object["status"] as? String == "excluded", "Classification request")
        let uploadDocument = try CSVParser.parse(data: Data("Name,Phone,Email\nNew contact,+12025550109,new@example.com\n".utf8), fileName: "additional.csv")
        let accountUpload = LeadWorkspaceViewModel(id: fixtures[1].id, repository: repo, inspector: AccountUploadInspector(document: uploadDocument))
        await accountUpload.load()
        await accountUpload.uploadSelectedFile(URL(fileURLWithPath: "/unused/additional.csv"))
        check(accountUpload.document == nil && !accountUpload.requiresColumnMapping, "Standard CSV should upload without a second screen")
        check(accountUpload.batches.contains { $0.fileName == "additional.csv" && $0.imported == 1 }, "Account upload must persist a file batch")
        check(accountUpload.workspace?.totalLeads == 3, "Account upload must refresh saved contact totals")
        let ambiguousDocument = try CSVParser.parse(data: Data("Name,Contact\nAnother,+12025550110\n".utf8), fileName: "ambiguous.csv")
        let ambiguous = LeadWorkspaceViewModel(id: fixtures[1].id, repository: repo, inspector: AccountUploadInspector(document: ambiguousDocument))
        await ambiguous.load()
        await ambiguous.uploadSelectedFile(URL(fileURLWithPath: "/unused/ambiguous.csv"))
        check(ambiguous.requiresColumnMapping && ambiguous.document != nil, "Ambiguous columns should request mapping instead of guessing")
        vm.clearImportError()
        vm.reportError(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
        check(vm.errorMessage == nil, "Dismissing the file picker is not an import failure")
        vm.reportError(CancellationError())
        check(vm.errorMessage == nil, "Cancelled tasks are not import failures")
        vm.reportError(CSVError.encoding)
        check(vm.errorMessage != nil, "Real file errors remain visible")
        vm.clearImportError()
        check(vm.errorMessage == nil, "Retrying clears the previous import error")
        print("Lead checks passed: preview/commit, deduplication, mapping, revisions, paused state, activity, owner access and HTTP adapter contracts.")
    }
}
