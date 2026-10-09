import Foundation

nonisolated protocol SessionServicing: APITokenProvider {
    func restore() async throws -> Bool
    func signIn(email: String, password: String) async throws
    func signOut() async throws
}
