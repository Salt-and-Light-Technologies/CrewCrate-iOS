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
actor SupabaseSession: SessionServicing {
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
