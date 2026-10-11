import Foundation

nonisolated protocol AuthenticationServicing: Sendable {
    func restore() async throws -> Bool
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws -> Bool
    func recover(email: String) async throws
    func updatePassword(_ password: String) async throws
    func acceptCallback(_ url: URL) async throws -> Bool
    func identity() async throws -> AuthenticatedIdentity
    func signOut() async throws
}

nonisolated struct AuthenticationFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
