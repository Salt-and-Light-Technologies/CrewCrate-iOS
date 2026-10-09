import Foundation

nonisolated protocol PartnerSetupRepository: Sendable {
    func setupPartners() async throws -> [LivePartner]
}
