import Foundation

nonisolated protocol CampaignWorkspaceServicing: Sendable {
    func campaigns(business: UUID) async throws -> [WorkspaceCampaign]
    func deleteCampaign(business: UUID, campaign: UUID, revision: Int) async throws
    func campaign(business: UUID, id: UUID) async throws -> WorkspaceCampaign
    func saveCampaign(business: UUID, original: WorkspaceCampaign?, settings: CampaignSettings) async throws -> WorkspaceCampaign
    func startPractice(business: UUID, settings: CampaignSettings) async throws -> PracticeConversation
    func practice(business: UUID, id: UUID) async throws -> PracticeConversation
    func reply(business: UUID, conversation: UUID, revision: Int, request: UUID, text: String) async throws -> PracticeConversation
    func columns(business: UUID, upload: ContactUpload, sheet: String) async throws -> UploadColumns
    func preview(business: UUID, upload: ContactUpload, mapping: UploadMapping) async throws -> UploadPreview
    func saveUpload(business: UUID, original: WorkspaceCampaign?, settings: CampaignSettings,
                    upload: ContactUpload, mapping: UploadMapping, preview: UploadPreview) async throws -> WorkspaceCampaign
}

extension SupabaseSession: CampaignWorkspaceServicing {
    func campaigns(business: UUID) async throws -> [WorkspaceCampaign] {
        var result: [WorkspaceCampaign] = []
        var offset = 0
        var seen: Set<UUID> = []
        while true {
            let page: [WorkspaceCampaign] = try await apiRequest("v1/partners/\(business)/campaigns", query: [
                URLQueryItem(name: "limit", value: "100"), URLQueryItem(name: "offset", value: String(offset))])
            for campaign in page where seen.insert(campaign.id).inserted { result.append(campaign) }
            if page.count < 100 { return result }
            offset += page.count
            try Task.checkCancellation()
        }
    }
    func deleteCampaign(business: UUID, campaign: UUID, revision: Int) async throws {
        let url = LiveConfiguration.apiURL.appendingPathComponent("v1/partners/\(business)/campaigns/\(campaign)")
            .appending(queryItems: [URLQueryItem(name: "expected_revision", value: String(revision))])
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = 30
        request.setValue("Bearer " + (try await accessToken()), forHTTPHeaderField: "Authorization")
        let (data, response) = try await sendAPIRequest(request)
        guard response.statusCode == 204 else {
            struct Failure: Decodable { let detail: String }
            let detail = (try? JSONDecoder().decode(Failure.self, from: data))?.detail
            let message = detail ?? "Couldn’t delete the campaign (HTTP \(response.statusCode)). Refresh the list before trying again."
            throw CrewCrateAPIError(status: response.statusCode, message: message)
        }
    }
    func campaign(business: UUID, id: UUID) async throws -> WorkspaceCampaign {
        try await apiRequest("v1/partners/\(business)/campaigns/\(id)")
    }
    func saveCampaign(business: UUID, original: WorkspaceCampaign?, settings: CampaignSettings) async throws -> WorkspaceCampaign {
        if let original {
            struct Update: Encodable { let expected_revision: Int; let config: CampaignSettings }
            return try await apiRequest("v1/partners/\(business)/campaigns/\(original.id)", method: "PUT",
                body: JSONEncoder().encode(Update(expected_revision: original.revision, config: settings)))
        }
        return try await apiRequest("v1/partners/\(business)/campaigns", method: "POST", body: JSONEncoder().encode(settings))
    }
    func startPractice(business: UUID, settings: CampaignSettings) async throws -> PracticeConversation {
        struct Create: Encodable { let config: CampaignSettings }
        return try await apiRequest("v1/partners/\(business)/ai-tests", method: "POST",
            body: JSONEncoder().encode(Create(config: settings)), timeout: 75)
    }
    func practice(business: UUID, id: UUID) async throws -> PracticeConversation {
        try await apiRequest("v1/partners/\(business)/ai-tests/\(id)")
    }
    func reply(business: UUID, conversation: UUID, revision: Int, request: UUID, text: String) async throws -> PracticeConversation {
        struct Turn: Encodable { let expected_revision: Int; let request_id: UUID; let text: String }
        return try await apiRequest("v1/partners/\(business)/ai-tests/\(conversation)/messages", method: "POST",
            body: JSONEncoder().encode(Turn(expected_revision: revision, request_id: request, text: text)), timeout: 75)
    }
    func columns(business: UUID, upload: ContactUpload, sheet: String) async throws -> UploadColumns {
        let fields = sheet.isEmpty ? [:] : ["sheet": sheet]
        let payload = multipart(upload: upload, fields: fields)
        return try await apiRequest("v1/partners/\(business)/imports/columns", method: "POST",
            body: payload.data, contentType: payload.contentType)
    }
    func preview(business: UUID, upload: ContactUpload, mapping: UploadMapping) async throws -> UploadPreview {
        let payload = multipart(upload: upload, fields: try mappingFields(mapping))
        return try await apiRequest("v1/partners/\(business)/imports/preview", method: "POST",
            body: payload.data, contentType: payload.contentType)
    }
    func saveUpload(business: UUID, original: WorkspaceCampaign?, settings: CampaignSettings,
                    upload: ContactUpload, mapping: UploadMapping, preview: UploadPreview) async throws -> WorkspaceCampaign {
        var fields = try mappingFields(mapping)
        fields["config"] = String(decoding: try JSONEncoder().encode(settings), as: UTF8.self)
        fields["expected_partner_revision"] = String(preview.partner_revision)
        fields["eligible_recipients_only"] = "true"
        if let original {
            fields["campaign_id"] = original.id.uuidString
            fields["expected_revision"] = String(original.revision)
        }
        let payload = multipart(upload: upload, fields: fields)
        return try await apiRequest("v1/partners/\(business)/campaign-import", method: "POST",
            body: payload.data, contentType: payload.contentType)
    }
    private func mappingFields(_ mapping: UploadMapping) throws -> [String: String] {
        var fields = ["phone_column": mapping.phone]
        if !mapping.name.isEmpty { fields["name_column"] = mapping.name }
        if !mapping.email.isEmpty { fields["email_column"] = mapping.email }
        if !mapping.sheet.isEmpty { fields["sheet"] = mapping.sheet }
        var permissions: [String: String] = [:]
        if !mapping.permission.isEmpty { permissions["permission"] = mapping.permission }
        if !mapping.evidence.isEmpty { permissions["evidence"] = mapping.evidence }
        if !mapping.optout.isEmpty { permissions["optout"] = mapping.optout }
        fields["permission_columns"] = String(decoding: try JSONEncoder().encode(permissions), as: UTF8.self)
        fields["permission_attested"] = mapping.permissionAttested ? "true" : "false"
        return fields
    }
    private func multipart(upload: ContactUpload, fields: [String: String]) -> (data: Data, contentType: String) {
        let boundary = "CrewCrate-" + UUID().uuidString
        var data = Data()
        func append(_ value: String) { data.append(Data(value.utf8)) }
        for key in fields.keys.sorted() {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(fields[key]!)\r\n")
        }
        let filename = upload.filename.replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\r", with: "_").replacingOccurrences(of: "\n", with: "_")
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\nContent-Type: application/octet-stream\r\n\r\n")
        data.append(upload.data)
        append("\r\n--\(boundary)--\r\n")
        return (data, "multipart/form-data; boundary=\(boundary)")
    }
}

nonisolated protocol ContactUploadReading: Sendable {
    func read(_ url: URL) async throws -> ContactUpload
}

actor ContactUploadReader: ContactUploadReading {
    func read(_ url: URL) async throws -> ContactUpload {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard ["csv", "tsv", "xlsx"].contains(url.pathExtension.lowercased()) else {
            throw AuthenticationFailure(message: "Choose a CSV, TSV or Excel .xlsx file.")
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 5_000_001) ?? Data()
        guard !data.isEmpty, data.count <= 5_000_000 else {
            throw AuthenticationFailure(message: "Choose a nonempty spreadsheet no larger than 5 MB.")
        }
        return ContactUpload(filename: url.lastPathComponent, data: data)
    }
}
