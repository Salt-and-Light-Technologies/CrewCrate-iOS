import Foundation

nonisolated enum DemoPartnerFixtures {
    static func make() -> [PartnerWorkspace] {
        func setup(_ name: String, industry: String, service: String) -> OnboardingDraft {
            var d = OnboardingDraft()
            d.contactName = "Sample partner administrator"; d.email = "partner@example.com"
            d.businessName = name; d.industry = industry; d.services = service
            d.serviceArea = "Example service area"; d.audience = [.dormant, .unclosed]
            d.offer = "Reconnect about \(service.lowercased())."; d.exclusions = "Active sales opportunities and opted-out contacts."
            d.qualification = "Interested in the service, in our service area, and ready to discuss next steps."
            d.salesContact = "Sample sales team"; d.handoffEmail = "sales@example.com"
            d.aiBoundaries = "Hand off pricing changes, guarantees, complaints and uncertain answers."
            d.leadSource = "Sample historical CRM export"; d.eligibilityNotes = "Sample eligibility evidence for demonstration only."
            d.importSummary = ImportSummary(fileName: "demo-leads.csv", totalRows: 1200, validContacts: 1000, duplicateContacts: 150, invalidContacts: 50, phoneColumn: "Phone")
            d.reportingSystem = "Sample CRM and payment records"
            d.commercialTerms = "Example only: 10% of attributed collected revenue after refunds, reconciled monthly."
            d.feeRate = 10
            d.acceptsVisibility = true; d.confirmsAccuracy = true; d.preparedAt = .now; d.savedStep = .review
            return d
        }
        let now = Date.now
        let ready = LaunchReadiness(eligibilityReviewed: true, messagingReady: true, reportingReady: true, agreementFinalized: true)
        let roofing = PartnerWorkspace(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, onboarding: setup("Summit Roofing · Sample", industry: "Roofing", service: "Roof inspections"), status: .submitted, readiness: ready, updatedAt: now)
        let dental = PartnerWorkspace(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, onboarding: setup("Bright Dental · Sample", industry: "Dental", service: "Consultations"), status: .submitted, readiness: LaunchReadiness(), updatedAt: now.addingTimeInterval(-3600))
        var consultingDraft = setup("Northstar Advisory · Sample", industry: "Consulting", service: "Business consultations")
        consultingDraft.qualification = ""; consultingDraft.importSummary = nil; consultingDraft.preparedAt = nil; consultingDraft.confirmsAccuracy = false
        let consulting = PartnerWorkspace(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, onboarding: consultingDraft, status: .draft, readiness: LaunchReadiness(), updatedAt: now.addingTimeInterval(-7200))
        return [roofing, dental, consulting]
    }
}
