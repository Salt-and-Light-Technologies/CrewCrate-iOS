import Foundation

nonisolated enum OnboardingStep: Int, CaseIterable, Codable, Identifiable {
    case account, business, recovery, sales, leads, reporting, review
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .account: "Account & team"
        case .business: "Your business"
        case .recovery: "Recovery goals"
        case .sales: "Sales process"
        case .leads: "Lead database"
        case .reporting: "Reporting & terms"
        case .review: "Launch review"
        }
    }
    var symbol: String {
        switch self {
        case .account: "person.2"
        case .business: "building.2"
        case .recovery: "arrow.clockwise"
        case .sales: "point.topleft.down.to.point.bottomright.curvepath"
        case .leads: "tray.and.arrow.down"
        case .reporting: "chart.bar.xaxis"
        case .review: "checkmark.shield"
        }
    }
    var subtitle: String {
        switch self {
        case .account: "Choose who will manage the partnership."
        case .business: "Tell us what you do. Every industry is welcome."
        case .recovery: "Define the audience and the next step you want."
        case .sales: "Give interested leads a clear path to your team."
        case .leads: "Inspect your list before planning a campaign."
        case .reporting: "Decide how outcomes and earnings will be checked."
        case .review: "Check your setup before preparing an owner review."
        }
    }
}
nonisolated enum RecoveryAudience: String, Codable, CaseIterable, Identifiable {
    case dormant = "Dormant prospects", unclosed = "Unclosed opportunities", customers = "Inactive customers"
    var id: String { rawValue }
}
nonisolated enum ConversionGoal: String, Codable, CaseIterable, Identifiable {
    case appointment = "Book an appointment", estimate = "Request an estimate", handoff = "Talk to sales", purchase = "Make a purchase"
    var id: String { rawValue }
}
nonisolated enum EvidenceSource: String, Codable, CaseIterable, Identifiable {
    // Keep uploaded-evidence drafts decodable; require a current source for new submissions.
    case manual = "Upload supporting evidence", crm = "Existing CRM", payments = "Invoicing or payment system"
    static var onboardingChoices: [EvidenceSource] { [.crm, .payments] }
    var id: String { rawValue }
}
nonisolated enum CompensationModel: String, Codable, CaseIterable, Identifiable {
    case revenue = "Share of collected revenue", appointment = "Qualified appointment fee", hybrid = "Monthly fee plus performance payment"
    var title: String { self == .hybrid ? "CrewCrate Membership plus Performance Payment" : rawValue }
    var id: String { rawValue }
}
nonisolated struct ImportSummary: Codable, Equatable, Sendable {
    var fileName: String
    var totalRows: Int
    var validContacts: Int
    var duplicateContacts: Int
    var invalidContacts: Int
    var phoneColumn: String
}
nonisolated struct OnboardingDraft: Codable, Equatable, Sendable {
    var schemaVersion = 1
    var contactName = ""
    var email = ""
    var teamEmails = ""
    var businessName = ""
    var website = ""
    var industry = ""
    var services = ""
    var serviceArea = ""
    var timeZone = TimeZone.current.identifier
    var audience: [RecoveryAudience] = []
    var dormantDays = 90
    var goal = ConversionGoal.appointment
    var offer = ""
    var exclusions = ""
    var qualification = ""
    var salesContact = ""
    var bookingURL = ""
    var handoffEmail = ""
    var responseHours = 24
    var aiBoundaries = ""
    var leadSource = ""
    var eligibilityNotes = ""
    var importSummary: ImportSummary?
    var evidenceSource = EvidenceSource.crm
    var reportingSystem = ""
    var compensation = CompensationModel.revenue
    var commercialTerms = ""
    var feeAmount: Double?
    var feeRate: Double?
    var attributionDays = 30
    var reportingDays = 7
    var acceptsVisibility = false
    var confirmsAccuracy = false
    var savedStep = OnboardingStep.account
    var preparedAt: Date?
}
nonisolated enum OnboardingValidation {
    static func nonempty(_ value: String) -> Bool { !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    static func email(_ value: String) -> Bool {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
    static func webURL(_ value: String) -> Bool {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host, host.contains(".") else { return false }
        return url.scheme == "https" || url.scheme == "http"
    }
    static func issues(for step: OnboardingStep, draft d: OnboardingDraft) -> [String] {
        var issues: [String] = []
        switch step {
        case .account:
            if !nonempty(d.contactName) { issues.append("Enter the partnership contact’s name.") }
            if !email(d.email) { issues.append("Enter a valid contact email address.") }
            let invites = d.teamEmails.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" })
            if invites.contains(where: { !email(String($0)) }) { issues.append("Check the optional team email addresses.") }
        case .business:
            if !nonempty(d.businessName) { issues.append("Enter your business name.") }
            if !nonempty(d.industry) { issues.append("Describe your industry in your own words.") }
            if !nonempty(d.services) { issues.append("Describe what you sell.") }
            if !nonempty(d.serviceArea) { issues.append("Enter your service area, or ‘Remote’.") }
            if nonempty(d.website) && !webURL(d.website) { issues.append("Use a website address beginning with https:// or http://.") }
            if TimeZone(identifier: d.timeZone) == nil { issues.append("Choose a valid time zone.") }
        case .recovery:
            if d.audience.isEmpty { issues.append("Select at least one recovery audience.") }
            if !nonempty(d.offer) { issues.append("Describe the offer or service to discuss.") }
        case .sales:
            if !nonempty(d.qualification) { issues.append("Define what makes a lead qualified.") }
            if !nonempty(d.salesContact) { issues.append("Name the person or team receiving interested leads.") }
            if !email(d.handoffEmail) { issues.append("Enter a valid handoff email address.") }
            if !nonempty(d.aiBoundaries) { issues.append("Define when the AI must ask a person for help.") }
            if nonempty(d.bookingURL) && !webURL(d.bookingURL) { issues.append("Check the booking link.") }
        case .leads:
            if !nonempty(d.leadSource) { issues.append("Describe where the list came from.") }
            if !nonempty(d.eligibilityNotes) { issues.append("Describe the contact-permission evidence and exclusions to review.") }
            // Upload is optional during setup; all contacts remain held for owner review.
        case .reporting:
            if !EvidenceSource.onboardingChoices.contains(d.evidenceSource) { issues.append("Choose an existing CRM or invoicing/payment system as your reporting source.") }
            if d.evidenceSource == .crm {
                let choice = CRMProvider.selection(for: d.reportingSystem)
                if choice == .notSelected { issues.append("Choose your CRM.") }
                if choice == .other && !nonempty(CRMProvider.customName(from: d.reportingSystem)) { issues.append("Enter the name of your CRM.") }
            } else if !nonempty(d.reportingSystem) { issues.append("Name where appointments, sales and payments are recorded.") }
            if !(d.feeAmount ?? 0).isFinite || !(0...1_000_000).contains(d.feeAmount ?? 0) { issues.append("Enter a fee amount between 0 and 1,000,000.") }
            if !(d.feeRate ?? 0).isFinite || !(0...100).contains(d.feeRate ?? 0) { issues.append("Enter a percentage rate between 0 and 100.") }
            if (d.feeAmount ?? 0) <= 0 && (d.feeRate ?? 0) <= 0 { issues.append("Choose a fee amount or percentage rate greater than zero.") }
            if !d.acceptsVisibility { issues.append("Acknowledge the owner’s visibility into partnership records.") }
        case .review:
            if !d.confirmsAccuracy { issues.append("Confirm that your setup is ready for review.") }
        }
        return issues
    }
    static func allIssues(_ draft: OnboardingDraft) -> [(OnboardingStep, String)] {
        OnboardingStep.allCases.flatMap { step in issues(for: step, draft: draft).map { (step, $0) } }
    }
}
