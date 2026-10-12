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
actor SupabaseSession: AuthenticationServicing {
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
        try await signupRequest(email: email, password: password, metadata: nil)
    }
    func signUp(email: String, password: String, business: BusinessApplicationDraft) async throws -> Bool {
        guard business.isComplete else { throw AuthenticationFailure(message: "Complete your business details before creating an account.") }
        let draft = String(decoding: try JSONEncoder().encode(business), as: UTF8.self)
        return try await signupRequest(email: email, password: password,
            metadata: ["crewcrate_business_application": draft])
    }
    private func signupRequest(email: String, password: String, metadata: [String: String]?) async throws -> Bool {
        generation += 1; let current = generation
        let data = try await authRequest(path: "signup", body: ["email": email, "password": password], redirect: true, metadata: metadata)
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
    func sendAPIRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await transport.send(request)
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
            struct Update: Encodable { let email: String?; let password: String?; let data: [String: String] }
            request.httpBody = try JSONEncoder().encode(Update(email: body?["email"], password: body?["password"], data: metadata))
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
