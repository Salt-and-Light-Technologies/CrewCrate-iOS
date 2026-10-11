import Foundation

nonisolated protocol AccountServicing: Sendable {
    func profile() async throws -> UserProfile
    func updateProfile(firstName: String, lastName: String, email: String?) async throws -> UserProfile
}

nonisolated protocol CampaignServicing: TestAIServicing, CampaignImportServicing, OutreachServicing {
    func workspaces() async throws -> [CampaignWorkspace]
    func campaigns(partnerID: UUID) async throws -> [CampaignSummary]
    func campaign(partnerID: UUID, campaignID: UUID) async throws -> CampaignSummary
    func updateCampaign(partnerID: UUID, campaignID: UUID, revision: Int, details: CampaignDetails) async throws -> CampaignSummary
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


nonisolated protocol TestAIServicing: Sendable {
    func startAITest(partnerID: UUID, campaignID: UUID?, config: CampaignDetails?) async throws -> AITestConversation
    func aiTest(partnerID: UUID, testID: UUID) async throws -> AITestConversation
    func sendAITest(partnerID: UUID, testID: UUID, revision: Int, requestID: UUID, text: String) async throws -> AITestConversation
}


nonisolated protocol BusinessServicing: Sendable {
    func businesses() async throws -> [BusinessWorkspace]
    func saveBusiness(id: UUID?, revision: Int?, details: BusinessDetails) async throws -> BusinessWorkspace
}


nonisolated protocol CampaignImportServicing: Sendable {
    func contactColumns(partnerID: UUID, file: ContactFile, sheet: String) async throws -> ImportColumns
    func previewContacts(partnerID: UUID, file: ContactFile, mapping: ContactMapping) async throws -> ContactPreview
    func saveCampaignWithContacts(partnerID: UUID, campaignID: UUID?, revision: Int?, details: CampaignDetails, file: ContactFile, mapping: ContactMapping, partnerRevision: Int) async throws -> CampaignSummary
}


nonisolated protocol OutreachServicing: Sendable {
    func campaignLeads(partnerID: UUID, campaignID: UUID?, importID: UUID?, eligibility: String, search: String, offset: Int) async throws -> [CampaignLead]
    func eligibleLeadIDs(partnerID: UUID, campaignID: UUID?, importID: UUID?, search: String) async throws -> [UUID]
    func leadBatches(partnerID: UUID) async throws -> [LeadBatch]
    func reviewLead(partnerID: UUID, leadID: UUID, review: LeadReview) async throws -> CampaignLead
    func selectRecipients(partnerID: UUID, campaignID: UUID, revision: Int, leadIDs: [UUID]) async throws -> RecipientSelectionResult
    func prepareCampaign(partnerID: UUID, campaignID: UUID, revision: Int) async throws -> CampaignSummary
    func startCampaign(partnerID: UUID, campaignID: UUID, revision: Int) async throws
}
