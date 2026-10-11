import Foundation

nonisolated protocol AccountServicing: Sendable {
    func profile() async throws -> UserProfile
    func updateProfile(firstName: String, lastName: String, email: String?) async throws -> UserProfile
}

nonisolated protocol CampaignServicing: Sendable {
    func workspaces() async throws -> [CampaignWorkspace]
    func campaigns(partnerID: UUID) async throws -> [CampaignSummary]
    func createCampaign(partnerID: UUID, details: CampaignDetails) async throws -> CampaignSummary
}

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
