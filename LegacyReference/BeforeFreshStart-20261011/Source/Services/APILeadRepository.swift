import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Ready for composition once the public API URL and Supabase session provider are available.
/// Tokens are supplied per request; this adapter does not persist credentials or choose user roles.
actor APILeadRepository: LeadRepository {
    private let baseURL: URL
    private let tokens: any APITokenProvider
    private let transport: any LeadHTTPTransport
    private let ownerWorkspace: Bool
    init(baseURL: URL, tokens: any APITokenProvider, ownerWorkspace: Bool, transport: any LeadHTTPTransport = URLSessionLeadTransport()) throws {
        guard baseURL.scheme == "https", baseURL.host != nil, baseURL.user == nil, baseURL.password == nil, baseURL.query == nil, baseURL.fragment == nil else { throw LeadAPIError.configuration }
        self.baseURL = baseURL; self.tokens = tokens; self.ownerWorkspace = ownerWorkspace; self.transport = transport
    }
    func request(_ path: String, method: String = "GET", query: [URLQueryItem] = [], body: Data? = nil, contentType: String? = nil) async throws -> Data {
        let token = try await tokens.accessToken()
        guard !token.isEmpty, !token.contains("\r"), !token.contains("\n") else { throw LeadAPIError.signIn }
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw LeadAPIError.configuration }
        var request = URLRequest(url: url)
        request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 30
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await transport.send(request)
        guard (200...299).contains(response.statusCode) else {
            switch response.statusCode {
            case 401: throw LeadAPIError.signIn
            case 403: throw LeadAPIError.forbidden
            case 404: throw LeadRepositoryError.missing
            case 409:
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                if let detail = object?["detail"] as? String, detail == "Import leads before submitting onboarding" {
                    throw LeadAPIError.server("The server still restricts CSV uploads to onboarding. The updated backend must be deployed to allow uploads from Account.")
                }
                if let detail = object?["detail"] as? String, detail == "CSV uploads are unavailable while the partner is paused" {
                    throw LeadAPIError.server(detail)
                }
                throw LeadAPIError.conflict
            case 413: throw LeadAPIError.tooLarge
            default:
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let detail = object?["detail"] as? String
                let checks = object?["detail"] as? [String: Any]
                let blockers = checks?["blockers"] as? [String] ?? checks?["onboarding_issues"] as? [String]
                throw LeadAPIError.server(detail ?? blockers?.joined(separator: "\n") ?? "The API could not complete this request (\(response.statusCode)).")
            }
        }
        return data
    }
    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { value in
            let text = try value.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plain = ISO8601DateFormatter()
            guard let date = fractional.date(from: text) ?? plain.date(from: text) else { throw LeadAPIError.invalidResponse }
            return date
        }
        do { return try decoder.decode(type, from: data) }
        catch { throw LeadAPIError.invalidResponse }
    }
    private func path(_ id: UUID, _ suffix: String) -> String { "v1/partners/\(id.uuidString)/\(suffix)" }
    private func page(_ offset: Int) -> [URLQueryItem] { [URLQueryItem(name: "limit", value: "50"), URLQueryItem(name: "offset", value: String(offset))] }
    func workspaces() async throws -> [LeadWorkspaceSummary] {
        var result: [LeadWorkspaceSummary] = [], offset = 0
        while true {
            if ownerWorkspace {
                let rows = try decode([SummaryDTO].self, from: await request("v1/owner/lead-workspaces", query: page(offset)))
                result += try rows.map { try $0.model() }
                if rows.count < 50 { break }
            } else {
                let rows = try decode([PartnerIDDTO].self, from: await request("v1/partners", query: page(offset)))
                for row in rows { result.append(try await workspace(id: row.id)) }
                if rows.count < 50 { break }
            }
            offset += 50
        }
        return result
    }
    func workspace(id: UUID) async throws -> LeadWorkspaceSummary {
        try decode(SummaryDTO.self, from: await request(path(id, "lead-workspace"))).model()
    }
    func leads(partnerID: UUID, search: String, status: LeadStatus?, offset: Int) async throws -> [LeadRecord] {
        var query = page(offset); query.append(URLQueryItem(name: "search", value: search))
        if let status { query.append(URLQueryItem(name: "status", value: status.rawValue)) }
        return try decode([LeadDTO].self, from: await request(path(partnerID, "leads"), query: query)).map { $0.model() }
    }
    func leadsInImport(partnerID: UUID, importID: UUID?, offset: Int) async throws -> [LeadRecord] {
        var query = page(offset)
        if let importID { query.append(URLQueryItem(name: "import_id", value: importID.uuidString)) }
        return try decode([LeadDTO].self, from: await request(path(partnerID, "leads"), query: query)).map { $0.model() }
    }
    func imports(partnerID: UUID, offset: Int) async throws -> [LeadImportBatch] {
        try decode([ImportDTO].self, from: await request(path(partnerID, "imports"), query: page(offset))).map { $0.model() }
    }
    func activity(partnerID: UUID, offset: Int) async throws -> [LeadActivity] {
        try decode([ActivityDTO].self, from: await request(path(partnerID, "lead-activity"), query: page(offset))).map { $0.model() }
    }
    private func upload(_ suffix: String, partnerID: UUID, document: CSVDocument, mapping: LeadColumnMapping, revision: Int?) async throws -> Data {
        let columns = [Optional(mapping.phone), mapping.name, mapping.email].compactMap { $0 }
        guard columns.allSatisfy(document.headers.indices.contains), Set(columns).count == columns.count else { throw LeadRepositoryError.invalidMapping }
        let boundary = "CrewCrate-" + UUID().uuidString
        var body = Data()
        func append(_ text: String) { body.append(Data(text.utf8)) }
        var fields = [("phone_column", document.headers[mapping.phone])]
        if let index = mapping.name { fields.append(("name_column", document.headers[index])) }
        if let index = mapping.email { fields.append(("email_column", document.headers[index])) }
        if let revision { fields.append(("expected_revision", String(revision))) }
        for (name, value) in fields {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        func csv(_ row: [String]) -> String { row.map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }.joined(separator: ",") }
        let contents = ([csv(document.headers)] + document.rows.map(csv)).joined(separator: "\r\n")
        guard contents.utf8.count <= 5_000_000 else { throw CSVError.tooLarge }
        let filename = document.fileName.replacingOccurrences(of: "\"", with: "_").replacingOccurrences(of: "\r", with: "_").replacingOccurrences(of: "\n", with: "_")
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\nContent-Type: text/csv\r\n\r\n\(contents)\r\n--\(boundary)--\r\n")
        return try await request(path(partnerID, suffix), method: "POST", body: body, contentType: "multipart/form-data; boundary=\(boundary)")
    }
    func preview(partnerID: UUID, document: CSVDocument, mapping: LeadColumnMapping) async throws -> LeadImportPreview {
        let dto = try decode(PreviewDTO.self, from: await upload("imports/preview", partnerID: partnerID, document: document, mapping: mapping, revision: nil))
        return LeadImportPreview(partnerRevision: dto.partnerRevision, totalRows: dto.totalRows, imported: dto.imported, duplicates: dto.duplicates, invalid: dto.invalid, issues: dto.issues, issuesTruncated: dto.issuesTruncated)
    }
    func importLeads(partnerID: UUID, document: CSVDocument, mapping: LeadColumnMapping, expectedRevision: Int) async throws -> LeadImportBatch {
        try decode(ImportDTO.self, from: await upload("imports", partnerID: partnerID, document: document, mapping: mapping, revision: expectedRevision)).model()
    }
    func classify(partnerID: UUID, leadID: UUID, status: LeadStatus, expectedRevision: Int) async throws -> LeadRecord {
        let body = try JSONSerialization.data(withJSONObject: ["status": status.rawValue, "expected_revision": expectedRevision])
        return try decode(LeadDTO.self, from: await request(path(partnerID, "leads/\(leadID.uuidString)"), method: "PATCH", body: body, contentType: "application/json")).model()
    }
}

nonisolated private struct PartnerIDDTO: Decodable { let id: UUID }
nonisolated private struct SummaryDTO: Decodable {
    let partnerId: UUID; let name: String; let status: String; let partnerRevision: Int
    let totalLeads: Int; let importCount: Int; let leadCounts: [String: Int]
    func model() throws -> LeadWorkspaceSummary {
        let statusMap: [String: PartnerStatus] = ["draft": .draft, "submitted": .submitted, "changes_requested": .changesRequested, "pilot_approved": .pilotApproved, "paused": .paused]
        guard let state = statusMap[status] else { throw LeadAPIError.invalidResponse }
        var counts: [LeadStatus: Int] = [:]
        for (key, count) in leadCounts {
            guard let status = LeadStatus(rawValue: key) else { throw LeadAPIError.invalidResponse }; counts[status] = count
        }
        return LeadWorkspaceSummary(id: partnerId, name: name, status: state, revision: partnerRevision, totalLeads: totalLeads, importCount: importCount, counts: counts)
    }
}
nonisolated private struct LeadDTO: Decodable {
    let smsPermission: String?; let permissionEvidence: String?; let optedOut: Bool?
    let id: UUID; let importId: UUID; let name: String; let phone: String; let email: String; let status: LeadStatus; let revision: Int
    func model() -> LeadRecord { LeadRecord(id: id, importID: importId, name: name, phone: phone, email: email, status: status, revision: revision, smsPermission: smsPermission ?? "unknown", permissionEvidence: permissionEvidence ?? "", optedOut: optedOut ?? false) }
}
nonisolated private struct ImportDTO: Decodable {
    let id: UUID; let fileName: String; let totalRows: Int; let imported: Int; let duplicates: Int; let invalid: Int; let timestamp: Date
    func model() -> LeadImportBatch { LeadImportBatch(id: id, fileName: fileName, totalRows: totalRows, imported: imported, duplicates: duplicates, invalid: invalid, timestamp: timestamp) }
}
nonisolated private struct ActivityDTO: Decodable {
    let id: UUID; let actorId: UUID; let action: String; let reason: String; let timestamp: Date
    func model() -> LeadActivity { LeadActivity(id: id, action: action == "leads_imported" ? "Leads imported" : (action == "sms_permission_updated" ? "SMS permission updated" : "Lead status changed"), actorName: actorId.uuidString, detail: reason, timestamp: timestamp) }
}
nonisolated private struct PreviewDTO: Decodable {
    let partnerRevision: Int; let totalRows: Int; let imported: Int; let duplicates: Int; let invalid: Int
    let issues: [LeadImportIssue]; let issuesTruncated: Bool
}


extension APILeadRepository {
    func setPermission(partnerID: UUID, leadID: UUID, permission: String, evidence: String, expectedRevision: Int) async throws -> LeadRecord {
        let body = try JSONSerialization.data(withJSONObject: ["permission": permission, "evidence": evidence, "expected_revision": expectedRevision])
        return try decode(LeadDTO.self, from: await request(path(partnerID, "leads/\(leadID.uuidString)/sms-permission"), method: "PUT", body: body, contentType: "application/json")).model()
    }
}

extension APILeadRepository: CampaignRepository {
    private func campaignPath(_ partnerID: UUID, _ id: UUID, _ suffix: String = "") -> String {
        path(partnerID, "campaigns/\(id.uuidString)" + (suffix.isEmpty ? "" : "/" + suffix))
    }
    private func json<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase; return try encoder.encode(value)
    }
    func campaigns(partnerID: UUID, offset: Int) async throws -> [CampaignRecord] {
        try decode([CampaignDTO].self, from: await request(path(partnerID, "campaigns"), query: page(offset))).map { $0.model() }
    }
    func campaign(partnerID: UUID, id: UUID) async throws -> CampaignRecord {
        try decode(CampaignDTO.self, from: await request(campaignPath(partnerID, id))).model()
    }
    func saveCampaign(partnerID: UUID, id: UUID?, config: CampaignConfig, expectedRevision: Int?) async throws -> CampaignRecord {
        let body: Data
        if let id {
            guard let expectedRevision else { throw CampaignError.conflict }
            body = try json(CampaignSaveDTO(expectedRevision: expectedRevision, config: CampaignConfigDTO(config)))
            return try decode(CampaignDTO.self, from: await request(campaignPath(partnerID, id), method: "PUT", body: body, contentType: "application/json")).model()
        } else {
            body = try json(CampaignConfigDTO(config))
            return try decode(CampaignDTO.self, from: await request(path(partnerID, "campaigns"), method: "POST", body: body, contentType: "application/json")).model()
        }
    }
    func prepareCampaign(partnerID: UUID, id: UUID, expectedRevision: Int) async throws -> CampaignRecord {
        let body = try JSONSerialization.data(withJSONObject: ["expected_revision": expectedRevision])
        return try decode(CampaignDTO.self, from: await request(campaignPath(partnerID, id, "prepare"), method: "POST", body: body, contentType: "application/json")).model()
    }
    func controlCampaign(partnerID: UUID, id: UUID, action: String, reason: String, expectedRevision: Int) async throws -> CampaignRecord {
        let body = try JSONSerialization.data(withJSONObject: ["expected_revision": expectedRevision, "action": action, "reason": reason])
        return try decode(CampaignDTO.self, from: await request(campaignPath(partnerID, id, "control"), method: "POST", body: body, contentType: "application/json")).model()
    }
    func campaignHistory(partnerID: UUID, id: UUID, offset: Int) async throws -> [CampaignActivity] {
        try decode([CampaignActivityDTO].self, from: await request(campaignPath(partnerID, id, "history"), query: page(offset))).map { $0.model() }
    }
    func conversations(partnerID: UUID, campaignID: UUID, offset: Int) async throws -> [ConversationRecord] {
        try decode([ConversationDTO].self, from: await request(campaignPath(partnerID, campaignID, "conversations"), query: page(offset))).map { $0.model() }
    }
    func trackConversation(partnerID: UUID, campaignID: UUID, leadID: UUID, note: String) async throws -> ConversationRecord {
        let body = try JSONSerialization.data(withJSONObject: ["lead_id": leadID.uuidString, "note": note])
        return try decode(ConversationDTO.self, from: await request(campaignPath(partnerID, campaignID, "conversations"), method: "POST", body: body, contentType: "application/json")).model()
    }
    func updateConversation(partnerID: UUID, campaignID: UUID, id: UUID, status: ConversationStatus, note: String, expectedRevision: Int) async throws -> ConversationRecord {
        let body = try JSONSerialization.data(withJSONObject: ["expected_revision": expectedRevision, "status": status.rawValue, "note": note])
        return try decode(ConversationDTO.self, from: await request(campaignPath(partnerID, campaignID, "conversations/\(id.uuidString)"), method: "PATCH", body: body, contentType: "application/json")).model()
    }
    func conversationHistory(partnerID: UUID, campaignID: UUID, id: UUID, offset: Int) async throws -> [ConversationNote] {
        try decode([ConversationNoteDTO].self, from: await request(campaignPath(partnerID, campaignID, "conversations/\(id.uuidString)/history"), query: page(offset))).map { $0.model() }
    }
}
nonisolated private struct CampaignConfigDTO: Codable {
    let startMinute: Int?
    let endMinute: Int?
    let aiName: String?
    let aiBrief: String?
    let name: String; let offer: String; let messageTemplate: String; let qualification: String; let handoffEmail: String
    let timeZone: String; let startHour: Int; let endHour: Int; let dailyLimit: Int; let followUpLimit: Int; let leadIds: [UUID]
    init(_ value: CampaignConfig) {
        startMinute = value.startMinute; endMinute = value.endMinute
        aiName = value.aiName
        aiBrief = value.aiBrief
        name = value.name; offer = value.offer; messageTemplate = value.messageTemplate; qualification = value.qualification; handoffEmail = value.handoffEmail
        timeZone = value.timeZone; startHour = value.startHour; endHour = value.endHour; dailyLimit = value.dailyLimit; followUpLimit = value.followUpLimit; leadIds = value.leadIDs
    }
    func model() -> CampaignConfig { CampaignConfig(name: name, offer: offer, aiBrief: aiBrief, aiName: aiName, messageTemplate: messageTemplate, qualification: qualification, handoffEmail: handoffEmail, timeZone: timeZone, startMinute: startMinute, endMinute: endMinute, startHour: startHour, endHour: endHour, dailyLimit: dailyLimit, followUpLimit: followUpLimit, leadIDs: leadIds) }
}
nonisolated private struct CampaignSaveDTO: Encodable { let expectedRevision: Int; let config: CampaignConfigDTO }
nonisolated private struct CampaignDTO: Decodable {
    let ownerHold: Bool?
    let id: UUID; let partnerId: UUID; let status: CampaignStatus; let revision: Int; let config: CampaignConfigDTO
    let updatedAt: Date; let blockers: [String]; let recipientCount: Int; let messagingConnected: Bool; let sendingEnabled: Bool; let needsRecheck: Bool
    func model() -> CampaignRecord { CampaignRecord(id: id, partnerID: partnerId, status: status, revision: revision, config: config.model(), updatedAt: updatedAt, blockers: blockers, recipientCount: recipientCount, needsRecheck: needsRecheck, ownerHold: ownerHold ?? false) }
}
nonisolated private struct CampaignActivityDTO: Decodable {
    let id: UUID; let action: String; let detail: String; let actorId: UUID; let timestamp: Date
    func model() -> CampaignActivity { CampaignActivity(id: id, action: action.replacingOccurrences(of: "_", with: " ").capitalized, detail: detail, actorName: actorId.uuidString, timestamp: timestamp) }
}
nonisolated private struct ConversationDTO: Decodable {
    let id: UUID; let campaignId: UUID; let leadId: UUID; let status: ConversationStatus; let revision: Int; let updatedAt: Date; let source: String
    func model() -> ConversationRecord { ConversationRecord(id: id, campaignID: campaignId, leadID: leadId, status: status, revision: revision, updatedAt: updatedAt) }
}
nonisolated private struct ConversationNoteDTO: Decodable {
    let id: UUID; let status: ConversationStatus; let note: String; let actorId: UUID; let timestamp: Date
    func model() -> ConversationNote { ConversationNote(id: id, status: status, note: note, actorName: actorId.uuidString, timestamp: timestamp) }
}
