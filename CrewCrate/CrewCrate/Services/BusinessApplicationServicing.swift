import Foundation

nonisolated protocol BusinessApplicationServicing: Sendable {
    func application() async throws -> BusinessApplication?
    func submitApplication(_ draft: BusinessApplicationDraft) async throws -> BusinessApplication
    func pendingApplications() async throws -> [BusinessApplication]
    func decide(_ application: BusinessApplication, approve: Bool, note: String) async throws -> BusinessApplication
    func businesses() async throws -> [BusinessSummary]
}

nonisolated private struct BusinessAPIFailure: Decodable { let detail: String }
nonisolated struct CrewCrateAPIError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}

extension SupabaseSession: BusinessApplicationServicing {
    func application() async throws -> BusinessApplication? {
        let existing: BusinessApplication? = try await apiRequest("v1/me/application")
        if let existing { return existing }
        // Trusted owner-provisioned businesses need no duplicate public application.
        if try await businesses().contains(where: { $0.access_approved == true }) { return nil }
        // Signup metadata preserves the draft through email verification and app reinstalls.
        // It grants no access: the API binds the resulting application to the verified user.
        var request = URLRequest(url: LiveConfiguration.authURL.appendingPathComponent("user"))
        request.timeoutInterval = 30
        request.setValue(LiveConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer " + (try await accessToken()), forHTTPHeaderField: "Authorization")
        let (data, response) = try await sendAPIRequest(request)
        guard response.statusCode == 200 else { throw AuthError.service }
        struct User: Decodable {
            struct Metadata: Decodable { let crewcrate_business_application: String? }
            let user_metadata: Metadata?
        }
        let user = try JSONDecoder().decode(User.self, from: data)
        guard let draftJSON = user.user_metadata?.crewcrate_business_application,
              let draft = try? JSONDecoder().decode(BusinessApplicationDraft.self, from: Data(draftJSON.utf8)),
              draft.isComplete else { return nil }
        return try await submitApplication(draft)
    }

    func submitApplication(_ draft: BusinessApplicationDraft) async throws -> BusinessApplication {
        try await apiRequest("v1/me/application", method: "POST", body: JSONEncoder().encode(draft))
    }

    func pendingApplications() async throws -> [BusinessApplication] {
        var result: [BusinessApplication] = []
        var offset = 0
        while true {
            let page: [BusinessApplication] = try await apiRequest("v1/owner/applications", query: [
                URLQueryItem(name: "limit", value: "100"), URLQueryItem(name: "offset", value: String(offset))
            ])
            result.append(contentsOf: page)
            if page.count < 100 { return result }
            offset += page.count
            try Task.checkCancellation()
        }
    }

    func decide(_ application: BusinessApplication, approve: Bool, note: String) async throws -> BusinessApplication {
        struct Decision: Encodable { let expected_revision: Int; let action: String; let note: String }
        return try await apiRequest("v1/owner/applications/\(application.id.uuidString)/decision", method: "POST",
            body: JSONEncoder().encode(Decision(expected_revision: application.revision,
                action: approve ? "approve" : "deny", note: note)))
    }

    func businesses() async throws -> [BusinessSummary] {
        var result: [BusinessSummary] = []
        var offset = 0
        while true {
            let page: [BusinessSummary] = try await apiRequest("v1/partners", query: [
                URLQueryItem(name: "limit", value: "100"), URLQueryItem(name: "offset", value: String(offset))
            ])
            result.append(contentsOf: page)
            if page.count < 100 { return result }
            offset += page.count
            try Task.checkCancellation()
        }
    }

    func apiRequest<T: Decodable & Sendable>(_ path: String, method: String = "GET",
        body: Data? = nil, query: [URLQueryItem] = [], contentType: String = "application/json",
        timeout: TimeInterval = 30) async throws -> T {
        var url = LiveConfiguration.apiURL.appendingPathComponent(path)
        if !query.isEmpty { url = url.appending(queryItems: query) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.httpBody = body
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + (try await accessToken()), forHTTPHeaderField: "Authorization")
        let (data, response) = try await sendAPIRequest(request)
        guard (200...299).contains(response.statusCode) else {
            let detail = (try? JSONDecoder().decode(BusinessAPIFailure.self, from: data))?.detail
            let resource = path.contains("owner/applications") ? "business requests" : "business information"
            let fallback: String
            switch response.statusCode {
            case 401: fallback = "Your session has expired. Log out and sign in again."
            case 403: fallback = "This account does not have permission to load \(resource)."
            case 404: fallback = "The deployed backend does not provide this feature. Check its deployment."
            case 500...599: fallback = "The server couldn’t load \(resource) (HTTP \(response.statusCode)). Check the Render error log; database migrations or server configuration may need attention."
            default: fallback = "Couldn’t load \(resource) (HTTP \(response.statusCode)). Please try again."
            }
            throw CrewCrateAPIError(status: response.statusCode, message: detail ?? fallback)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
