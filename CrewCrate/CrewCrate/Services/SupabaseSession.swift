import Foundation

nonisolated enum AuthError: LocalizedError {
    case signedOut, credentials, storage, response, service
    var errorDescription: String? {
        switch self {
        case .signedOut: "Please sign in again."
        case .credentials: "Sign-in failed. Check your email and password."
        case .storage: "Your session could not be stored securely. Please try again."
        case .response: "The authentication response was not recognized."
        case .service: "Couldn’t reach authentication. Please try again."
        }
    }
}
actor SupabaseSession: AuthenticationServicing, AccountServicing, CampaignServicing, BusinessServicing {
    private let store: any AuthSessionStore
    private let transport: any LeadHTTPTransport
    private var session: AuthSession?
    private var refreshTask: Task<AuthSession, Error>?
    private var generation = 0
    init(store: any AuthSessionStore = KeychainSessionStore(), transport: any LeadHTTPTransport = URLSessionLeadTransport()) { self.store = store; self.transport = transport }
    func restore() async throws -> Bool {
        session = try store.load()
        guard session != nil else { return false }
        _ = try await accessToken(); return true
    }
    func signIn(email: String, password: String) async throws {
        generation += 1; let current = generation
        let value = try await exchange(grant: "password", body: ["email": email, "password": password])
        guard current == generation else { throw AuthError.signedOut }
        try store.save(value); session = value
    }
    func accessToken() async throws -> String {
        guard let old = session else { throw AuthError.signedOut }
        if old.expiresAt.timeIntervalSinceNow > 60 { return old.accessToken }
        let current = generation
        let task: Task<AuthSession, Error>
        if let pending = refreshTask { task = pending }
        else {
            task = Task { try await self.exchange(grant: "refresh_token", body: ["refresh_token": old.refreshToken]) }
            refreshTask = task
        }
        do {
            let new = try await task.value
            guard current == generation else { throw AuthError.signedOut }
            guard new.userID == old.userID else { throw AuthError.response }
            try store.save(new); session = new; refreshTask = nil
            return new.accessToken
        } catch {
            if current == generation {
                refreshTask = nil
                if let auth = error as? AuthError, case .credentials = auth { session = nil; try store.clear() }
            }
            throw error
        }
    }
    func signOut() async throws {
        let token = session?.accessToken
        generation += 1; refreshTask?.cancel(); refreshTask = nil; session = nil
        try store.clear()
        if let token {
            var request = URLRequest(url: LiveConfiguration.authURL.appendingPathComponent("logout").appending(queryItems: [URLQueryItem(name: "scope", value: "local")]))
            request.httpMethod = "POST"; request.timeoutInterval = 15
            request.setValue(LiveConfiguration.publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            let (_, response) = try await transport.send(request)
            guard (200...299).contains(response.statusCode) || response.statusCode == 401 else { throw AuthError.service }
        }
    }
    func signUp(email: String, password: String) async throws -> Bool {
        generation += 1; let current = generation
        let data = try await authRequest(path: "signup", body: ["email": email, "password": password], redirect: true)
        struct Result: Decodable { let access_token: String? }
        let result = try JSONDecoder().decode(Result.self, from: data)
        guard result.access_token != nil else { return false }
        let value = try decodeSession(data)
        guard current == generation else { throw AuthError.signedOut }
        try store.save(value); session = value
        return true
    }
    func recover(email: String) async throws {
        _ = try await authRequest(path: "recover", body: ["email": email], redirect: true)
    }
    func updatePassword(_ password: String) async throws {
        _ = try await authRequest(path: "user", body: ["password": password], method: "PUT", token: try await accessToken())
    }
    func acceptCallback(_ url: URL) async throws -> Bool {
        guard url.scheme == "crewcrate", url.host == "auth" else { throw AuthError.response }
        let parts = URLComponents(string: "https://callback.invalid/?" + (url.fragment ?? ""))?.queryItems ?? []
        func value(_ key: String) -> String? { parts.first { $0.name == key }?.value }
        if value("error") != nil { throw AuthError.response }
        guard let access = value("access_token"), let refresh = value("refresh_token"),
              !access.isEmpty, !refresh.isEmpty else { throw AuthError.response }
        // Validate callback credentials against Supabase rather than trusting URL claims.
        generation += 1; let current = generation
        let data = try await authRequest(path: "user", body: nil, method: "GET", token: access)
        struct User: Decodable { let id: UUID }
        let user = try JSONDecoder().decode(User.self, from: data)
        let expires = Double(value("expires_in") ?? "0") ?? 0
        guard expires > 0 else { throw AuthError.response }
        guard current == generation else { throw AuthError.signedOut }
        refreshTask?.cancel(); refreshTask = nil
        let new = AuthSession(accessToken: access, refreshToken: refresh, expiresAt: Date().addingTimeInterval(expires), userID: user.id)
        try store.save(new); session = new
        return value("type") == "recovery"
    }
    func identity() async throws -> AuthenticatedIdentity {
        var request = URLRequest(url: LiveConfiguration.apiURL.appendingPathComponent("v1/me"))
        request.timeoutInterval = 30
        request.setValue("Bearer " + (try await accessToken()), forHTTPHeaderField: "Authorization")
        let (data, response) = try await transport.send(request)
        guard response.statusCode == 200 else {
            if response.statusCode == 401 { throw AuthError.signedOut }
            throw AuthError.service
        }
        let identity = try JSONDecoder().decode(AuthenticatedIdentity.self, from: data)
        guard identity.userID == session?.userID else { throw AuthError.response }
        return identity
    }
    func workspaces() async throws -> [CampaignWorkspace] {
        var values: [CampaignWorkspace] = []
        while true {
            let data = try await backendRequest(path: "v1/partners", offset: values.count)
            let page = try JSONDecoder().decode([CampaignWorkspace].self, from: data)
            values += page
            if page.count < 100 { return values }
        }
    }
    func campaigns(partnerID: UUID) async throws -> [CampaignSummary] {
        var values: [CampaignSummary] = []
        while true {
            let data = try await backendRequest(path: "v1/partners/\(partnerID)/campaigns", offset: values.count)
            let page = try JSONDecoder().decode([CampaignSummary].self, from: data)
            values += page
            if page.count < 100 { return values }
        }
    }
    func createCampaign(partnerID: UUID, details: CampaignDetails) async throws -> CampaignSummary {
        let data = try await backendRequest(path: "v1/partners/\(partnerID)/campaigns", body: JSONEncoder().encode(details))
        return try JSONDecoder().decode(CampaignSummary.self, from: data)
    }
    func campaign(partnerID: UUID, campaignID: UUID) async throws -> CampaignSummary {
        let data = try await backendRequest(path: "v1/partners/\(partnerID)/campaigns/\(campaignID)")
        return try JSONDecoder().decode(CampaignSummary.self, from: data)
    }
    func updateCampaign(partnerID: UUID, campaignID: UUID, revision: Int, details: CampaignDetails) async throws -> CampaignSummary {
        struct Update: Encodable { let expected_revision: Int; let config: CampaignDetails }
        let data = try await backendRequest(path: "v1/partners/\(partnerID)/campaigns/\(campaignID)",
                                            body: JSONEncoder().encode(Update(expected_revision: revision, config: details)), method: "PUT")
        return try JSONDecoder().decode(CampaignSummary.self, from: data)
    }
    func startAITest(partnerID: UUID, campaignID: UUID?, config: CampaignDetails?) async throws -> AITestConversation {
        struct Start: Encodable {
            let campaign_id: UUID?
            let config: CampaignDetails?
        }
        let data = try await backendRequest(path: "v1/partners/\(partnerID)/ai-tests", body: JSONEncoder().encode(Start(campaign_id: campaignID, config: config)))
        return try JSONDecoder().decode(AITestConversation.self, from: data)
    }
    func aiTest(partnerID: UUID, testID: UUID) async throws -> AITestConversation {
        let data = try await backendRequest(path: "v1/partners/\(partnerID)/ai-tests/\(testID)")
        return try JSONDecoder().decode(AITestConversation.self, from: data)
    }
    func sendAITest(partnerID: UUID, testID: UUID, revision: Int, requestID: UUID, text: String) async throws -> AITestConversation {
        struct Turn: Encodable {
            let expected_revision: Int
            let request_id: UUID
            let text: String
        }
        let data = try await backendRequest(path: "v1/partners/\(partnerID)/ai-tests/\(testID)/messages", body: JSONEncoder().encode(Turn(expected_revision: revision, request_id: requestID, text: text)))
        return try JSONDecoder().decode(AITestConversation.self, from: data)
    }
    func businesses() async throws -> [BusinessWorkspace] {
        var result: [BusinessWorkspace] = []
        while true {
            let data = try await backendRequest(path: "v1/partners", offset: result.count)
            let page = try JSONDecoder().decode([BusinessWorkspace].self, from: data)
            result += page
            if page.count < 100 { return result }
        }
    }
    func saveBusiness(id: UUID?, revision: Int?, details: BusinessDetails) async throws -> BusinessWorkspace {
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(details)) as! [String: Any]
        if let revision { object["expected_revision"] = revision }
        let data = try await backendRequest(path: id.map { "v1/partners/\($0)/business" } ?? "v1/me/business",
                                            body: JSONSerialization.data(withJSONObject: object), method: id == nil ? "POST" : "PUT")
        return try JSONDecoder().decode(BusinessWorkspace.self, from: data)
    }
    func contactColumns(partnerID: UUID, file: ContactFile, sheet: String) async throws -> ImportColumns {
        let data = try await uploadContacts(path: "v1/partners/\(partnerID)/imports/columns", file: file, fields: sheet.isEmpty ? [:] : ["sheet": sheet])
        return try JSONDecoder().decode(ImportColumns.self, from: data)
    }
    private func mappingFields(_ mapping: ContactMapping) -> [String: String] {
        var fields = ["phone_column": mapping.phone]
        if !mapping.name.isEmpty { fields["name_column"] = mapping.name }
        if !mapping.email.isEmpty { fields["email_column"] = mapping.email }
        if !mapping.sheet.isEmpty { fields["sheet"] = mapping.sheet }
        return fields
    }
    func previewContacts(partnerID: UUID, file: ContactFile, mapping: ContactMapping) async throws -> ContactPreview {
        let data = try await uploadContacts(path: "v1/partners/\(partnerID)/imports/preview", file: file, fields: mappingFields(mapping))
        return try JSONDecoder().decode(ContactPreview.self, from: data)
    }
    func saveCampaignWithContacts(partnerID: UUID, campaignID: UUID?, revision: Int?, details: CampaignDetails, file: ContactFile, mapping: ContactMapping, partnerRevision: Int) async throws -> CampaignSummary {
        var fields = mappingFields(mapping)
        fields["config"] = String(data: try JSONEncoder().encode(details), encoding: .utf8)
        fields["expected_partner_revision"] = String(partnerRevision)
        fields["campaign_id"] = campaignID?.uuidString
        fields["expected_revision"] = revision.map(String.init)
        let data = try await uploadContacts(path: "v1/partners/\(partnerID)/campaign-import", file: file, fields: fields)
        return try JSONDecoder().decode(CampaignSummary.self, from: data)
    }
    private func uploadContacts(path: String, file: ContactFile, fields: [String: String]) async throws -> Data {
        guard file.data.count <= 5_000_000 else { throw AuthenticationFailure(message: "Choose a file smaller than 5 MB.") }
        let boundary = "CrewCrate-" + UUID().uuidString
        var body = Data()
        func append(_ value: String) { body.append(Data(value.utf8)) }
        for (key, value) in fields.sorted(by: { $0.key < $1.key }) {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n")
        }
        let filename = file.name.replacingOccurrences(of: "\"", with: "_").replacingOccurrences(of: "\r", with: "_").replacingOccurrences(of: "\n", with: "_")
        append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\nContent-Type: application/octet-stream\r\n\r\n")
        body.append(file.data)
        append("\r\n--\(boundary)--\r\n")
        return try await backendRequest(path: path, body: body, contentType: "multipart/form-data; boundary=\(boundary)")
    }
    private func backendRequest(path: String, offset: Int? = nil, body: Data? = nil, method: String? = nil, contentType: String = "application/json") async throws -> Data {
        var url = LiveConfiguration.apiURL.appendingPathComponent(path)
        if let offset { url = url.appending(queryItems: [URLQueryItem(name: "limit", value: "100"), URLQueryItem(name: "offset", value: String(offset))]) }
        var request = URLRequest(url: url)
        request.timeoutInterval = path.contains("ai-tests") ? 75 : 30
        request.httpMethod = method ?? (body == nil ? "GET" : "POST")
        request.httpBody = body
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + (try await accessToken()), forHTTPHeaderField: "Authorization")
        let (data, response) = try await transport.send(request)
        guard (200...299).contains(response.statusCode) else {
            struct Failure: Decodable { let detail: String }
            let message = (try? JSONDecoder().decode(Failure.self, from: data))?.detail
            throw AuthenticationFailure(message: message ?? "Couldn’t load or save campaigns. Please try again.")
        }
        return data
    }
    func profile() async throws -> UserProfile {
        let data = try await authRequest(path: "user", body: nil, method: "GET", token: try await accessToken())
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }
    func updateProfile(firstName: String, lastName: String, email: String?) async throws -> UserProfile {
        let data = try await authRequest(path: "user", body: email.map { ["email": $0] }, method: "PUT", token: try await accessToken(), redirect: email != nil, metadata: ["first_name": firstName, "last_name": lastName])
        return try JSONDecoder().decode(UserProfile.self, from: data)
    }
    private func authRequest(path: String, body: [String: String]?, method: String = "POST", token: String? = nil, redirect: Bool = false, metadata: [String: String]? = nil) async throws -> Data {
        var url = LiveConfiguration.authURL.appendingPathComponent(path)
        if redirect { url = url.appending(queryItems: [URLQueryItem(name: "redirect_to", value: "crewcrate://auth")]) }
        var request = URLRequest(url: url)
        request.httpMethod = method; request.timeoutInterval = 30
        request.setValue(LiveConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if let metadata {
            struct Update: Encodable { let email: String?; let data: [String: String] }
            request.httpBody = try JSONEncoder().encode(Update(email: body?["email"], data: metadata))
        } else if let body { request.httpBody = try JSONEncoder().encode(body) }
        let (data, response) = try await transport.send(request)
        guard (200...299).contains(response.statusCode) else {
            struct Failure: Decodable { let msg: String?; let message: String? }
            let failure = try? JSONDecoder().decode(Failure.self, from: data)
            throw AuthenticationFailure(message: failure?.msg ?? failure?.message ?? "Authentication failed. Please try again.")
        }
        return data
    }
    private func decodeSession(_ data: Data) throws -> AuthSession {
        struct Token: Decodable {
            struct User: Decodable { let id: UUID }
            let access_token: String; let refresh_token: String; let expires_in: Double; let user: User
        }
        let token = try JSONDecoder().decode(Token.self, from: data)
        guard !token.access_token.isEmpty, !token.refresh_token.isEmpty, token.expires_in > 0 else { throw AuthError.response }
        return AuthSession(accessToken: token.access_token, refreshToken: token.refresh_token, expiresAt: Date().addingTimeInterval(token.expires_in), userID: token.user.id)
    }
    private func exchange(grant: String, body: [String: String]) async throws -> AuthSession {
        var request = URLRequest(url: LiveConfiguration.authURL.appendingPathComponent("token").appending(queryItems: [URLQueryItem(name: "grant_type", value: grant)]))
        request.httpMethod = "POST"; request.timeoutInterval = 30
        request.setValue(LiveConfiguration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await transport.send(request)
        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 422 { throw AuthError.credentials }
            throw AuthError.service
        }
        struct Token: Decodable {
            struct User: Decodable { let id: UUID }
            let access_token: String; let refresh_token: String; let expires_in: Double; let user: User
        }
        guard let token = try? JSONDecoder().decode(Token.self, from: data), !token.access_token.isEmpty, !token.refresh_token.isEmpty, token.expires_in > 0 else { throw AuthError.response }
        return AuthSession(accessToken: token.access_token, refreshToken: token.refresh_token, expiresAt: Date().addingTimeInterval(token.expires_in), userID: token.user.id)
    }
}
