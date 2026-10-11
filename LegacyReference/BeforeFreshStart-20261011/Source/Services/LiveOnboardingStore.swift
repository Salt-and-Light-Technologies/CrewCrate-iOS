import Foundation

nonisolated protocol ReviewSubmittingStore: DraftStore {
    func submit() async throws
}
nonisolated protocol OnboardingContactImporting: Sendable {
    func importContacts(_ document: CSVDocument, phoneColumn: Int) async throws -> ImportSummary
}
actor LiveOnboardingStore: ReviewSubmittingStore, OnboardingContactImporting {
    private let api: APILeadRepository
    private let partnerID: UUID
    private var revision: Int?
    init(api: APILeadRepository, partnerID: UUID) { self.api = api; self.partnerID = partnerID }
    private var path: String { "v1/partners/\(partnerID.uuidString)" }
    func load() async throws -> OnboardingDraft? {
        let data = try await api.request(path)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rev = object["revision"] as? Int, var setup = object["onboarding"] as? [String: Any], let status = object["status"] as? String else { throw LeadAPIError.invalidResponse }
        revision = rev
        let defaultsEncoder = JSONEncoder(); defaultsEncoder.keyEncodingStrategy = .convertToSnakeCase
        let defaults = try JSONSerialization.jsonObject(with: defaultsEncoder.encode(OnboardingDraft())) as! [String: Any]
        setup = defaults.merging(setup) { _, server in server }
        let goals = ["appointment": ConversionGoal.appointment.rawValue, "estimate": ConversionGoal.estimate.rawValue, "handoff": ConversionGoal.handoff.rawValue, "purchase": ConversionGoal.purchase.rawValue]
        let sources = ["manual": EvidenceSource.manual.rawValue, "crm": EvidenceSource.crm.rawValue, "payments": EvidenceSource.payments.rawValue]
        let payments = ["revenue": CompensationModel.revenue.rawValue, "appointment": CompensationModel.appointment.rawValue, "hybrid": CompensationModel.hybrid.rawValue]
        setup["goal"] = goals[setup["goal"] as? String ?? ""] ?? ConversionGoal.appointment.rawValue
        setup["evidence_source"] = sources[setup["evidence_source"] as? String ?? ""] ?? EvidenceSource.manual.rawValue
        setup["compensation"] = payments[setup["compensation"] as? String ?? ""] ?? CompensationModel.revenue.rawValue
        let audience = ["dormant": RecoveryAudience.dormant.rawValue, "unclosed": RecoveryAudience.unclosed.rawValue, "customers": RecoveryAudience.customers.rawValue]
        setup["audience"] = (setup["audience"] as? [String] ?? []).compactMap { audience[$0] }
        setup["team_emails"] = (setup["team_emails"] as? [String] ?? []).joined(separator: ", ")
        if (setup["time_zone"] as? String ?? "").isEmpty { setup["time_zone"] = TimeZone.current.identifier }
        setup["schema_version"] = 1; setup["saved_step"] = 0
        if status != "draft" && status != "changes_requested" { setup["prepared_at"] = Date().timeIntervalSinceReferenceDate }
        // Explicit URL fields avoid Foundation's acronym conversion ambiguity.
        setup["bookingURL"] = setup.removeValue(forKey: "booking_url")
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(OnboardingDraft.self, from: JSONSerialization.data(withJSONObject: setup))
    }
    func save(_ draft: OnboardingDraft) async throws {
        guard let revision else { throw LeadAPIError.conflict }
        let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase
        var setup = try JSONSerialization.jsonObject(with: encoder.encode(draft)) as! [String: Any]
        for key in ["schema_version", "saved_step", "prepared_at", "import_summary"] { setup.removeValue(forKey: key) }
        setup["team_emails"] = draft.teamEmails.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" }).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        setup["goal"] = [ConversionGoal.appointment: "appointment", .estimate: "estimate", .handoff: "handoff", .purchase: "purchase"][draft.goal]
        setup["evidence_source"] = [EvidenceSource.manual: "manual", .crm: "crm", .payments: "payments"][draft.evidenceSource]
        setup["compensation"] = [CompensationModel.revenue: "revenue", .appointment: "appointment", .hybrid: "hybrid"][draft.compensation]
        setup["audience"] = draft.audience.map { [RecoveryAudience.dormant: "dormant", .unclosed: "unclosed", .customers: "customers"][$0]! }
        let body = try JSONSerialization.data(withJSONObject: ["expected_revision": revision, "onboarding": setup])
        let data = try await api.request(path + "/onboarding", method: "PUT", body: body, contentType: "application/json")
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], let updated = object["revision"] as? Int else { throw LeadAPIError.invalidResponse }
        self.revision = updated
    }
    func importContacts(_ document: CSVDocument, phoneColumn: Int) async throws -> ImportSummary {
        let mapping = LeadColumnMapping(phone: phoneColumn,
            name: document.headers.firstIndex { $0.lowercased() == "name" },
            email: document.headers.firstIndex { $0.lowercased() == "email" })
        let preview = try await api.preview(partnerID: partnerID, document: document, mapping: mapping)
        let batch = try await api.importLeads(partnerID: partnerID, document: document, mapping: mapping, expectedRevision: preview.partnerRevision)
        let workspace = try await api.workspace(id: partnerID)
        revision = workspace.revision
        return ImportSummary(fileName: batch.fileName, totalRows: batch.totalRows, validContacts: batch.imported, duplicateContacts: batch.duplicates, invalidContacts: batch.invalid, phoneColumn: document.headers[phoneColumn])
    }
    func submit() async throws {
        guard let revision else { throw LeadAPIError.conflict }
        let data = try await api.request(path + "/submit", method: "POST", body: JSONSerialization.data(withJSONObject: ["expected_revision": revision]), contentType: "application/json")
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], let updated = object["revision"] as? Int else { throw LeadAPIError.invalidResponse }
        self.revision = updated
    }
}
