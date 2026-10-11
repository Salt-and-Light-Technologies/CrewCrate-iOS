import Foundation

nonisolated enum PartnerStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case draft = "Draft", submitted = "Awaiting review", changesRequested = "Changes requested"
    case pilotApproved = "Pilot approved", paused = "Paused"
    var id: String { rawValue }
}
nonisolated enum ReviewAction: String, Codable, Sendable {
    case approve = "Pilot approved", requestChanges = "Changes requested", pause = "Paused", resume = "Resumed"
}
nonisolated struct LaunchReadiness: Codable, Equatable, Sendable {
    var eligibilityReviewed = false
    var messagingReady = false
    var reportingReady = false
    var agreementFinalized = false
}
nonisolated struct ReviewEvent: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let action: ReviewAction
    let previousStatus: PartnerStatus
    let resultingStatus: PartnerStatus
    let actorName: String
    let reason: String
    let timestamp: Date
}
nonisolated struct PartnerWorkspace: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var onboarding: OnboardingDraft
    var status: PartnerStatus
    var readiness: LaunchReadiness
    var revision = 0
    var updatedAt: Date
    var history: [ReviewEvent] = []
    var pausedFrom: PartnerStatus?
    var name: String { onboarding.businessName }
    var missingLaunchRequirements: [String] {
        var missing = OnboardingValidation.allIssues(onboarding).map { "\($0.0.title): \($0.1)" }
        if onboarding.importSummary == nil { missing.append("Lead database has not been provided.") }
        if !readiness.eligibilityReviewed { missing.append("Contact eligibility needs review.") }
        if !readiness.messagingReady { missing.append("Messaging setup is incomplete.") }
        if !readiness.reportingReady { missing.append("Reporting sources are not ready.") }
        if !readiness.agreementFinalized { missing.append("The commercial agreement is not finalized.") }
        return missing
    }
    var canApprove: Bool { status == .submitted && missingLaunchRequirements.isEmpty }
    var canRequestChanges: Bool { status == .submitted }
}
nonisolated enum PartnerRepositoryError: LocalizedError {
    case notFound, conflict, invalidTransition, missingRequirements, reasonRequired
    var errorDescription: String? {
        switch self {
        case .notFound: "This partner is no longer available. Refresh the list."
        case .conflict: "This partner changed since you opened it. Refresh before making a decision."
        case .invalidTransition: "That action isn’t available for the current partner status."
        case .missingRequirements: "Complete the launch requirements before approving a pilot."
        case .reasonRequired: "Add a reason with at least five characters."
        }
    }
}
