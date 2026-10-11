import Foundation

nonisolated enum CheckError: Error { case failed(String) }
nonisolated func check(_ condition: Bool, _ message: String) throws {
    if !condition { throw CheckError.failed(message) }
}
actor FailingStore: DraftStore {
    let failLoad: Bool
    init(failLoad: Bool = false) { self.failLoad = failLoad }
    func load() async throws -> OnboardingDraft? {
        if failLoad { throw CheckError.failed("Load unavailable") }
        return nil
    }
    func save(_ draft: OnboardingDraft) async throws { throw CheckError.failed("Save unavailable") }
}

@main struct OnboardingChecks {
    @MainActor static func main() async throws {
        let csv = "\u{FEFF}Name,Phone,Notes\r\n\"Sam, Jones\",+1 (555) 123-4567,\"Line one\nLine two\"\r\nAlex,15551234567,\"Said \"\"hello\"\"\"\r\nPat,invalid,Missing\r\n"
        let document = try CSVParser.parse(data: Data(csv.utf8), fileName: "test.csv")
        try check(document.rows[0][0] == "Sam, Jones", "Quoted commas must survive")
        try check(document.rows[0][2].contains("\n"), "Quoted multiline fields must survive")
        try check(document.rows[1][2] == "Said \"hello\"", "Escaped quotes must survive")
        let summary = try CSVParser.summarize(document, phoneIndex: 1)
        try check(summary.totalRows == 3 && summary.validContacts == 1 && summary.duplicateContacts == 1 && summary.invalidContacts == 1, "Import counts must reconcile")
        for malformed in ["Name,Phone\n\"Unclosed,123", "Name,Phone\nA,123,extra", "Name,name\nA,B", "Name,Phone\nA\"x,123", "Name,Phone\n\"A\"x,123"] {
            do {
                _ = try CSVParser.parse(data: Data(malformed.utf8), fileName: "invalid.csv")
                throw CheckError.failed("Malformed CSV was accepted")
            } catch is CSVError { }
        }
        var draft = OnboardingDraft()
        try check(!OnboardingValidation.allIssues(draft).isEmpty, "Empty setup must fail validation")
        draft.contactName = "Partner Owner"; draft.email = "owner@example.com"
        draft.businessName = "Example business"; draft.industry = "Custom industry"
        draft.services = "Consultations"; draft.serviceArea = "Remote"
        draft.audience = [.dormant, .customers]; draft.offer = "Discuss your needs"
        draft.qualification = "Interested in a consultation"; draft.salesContact = "Sales team"
        draft.handoffEmail = "sales@example.com"; draft.aiBoundaries = "Refer pricing changes"
        draft.leadSource = "Partner’s existing CRM"; draft.eligibilityNotes = "Records need owner review"
        draft.reportingSystem = "Evidence uploads"; draft.commercialTerms = "10% of verified collections after refunds"
        draft.feeRate = 10
        draft.acceptsVisibility = true; draft.confirmsAccuracy = true
        try check(OnboardingValidation.allIssues(draft).isEmpty, "Custom industry should complete setup without a CSV")
        draft.feeRate = nil
        try check(!OnboardingValidation.issues(for: .reporting, draft: draft).isEmpty, "Missing amount and rate must block continuation")
        draft.feeAmount = 0; draft.feeRate = 0
        try check(!OnboardingValidation.issues(for: .reporting, draft: draft).isEmpty, "Two zero values must block continuation")
        draft.feeAmount = 25
        try check(OnboardingValidation.issues(for: .reporting, draft: draft).isEmpty, "Amount alone must allow continuation")
        draft.feeAmount = nil; draft.feeRate = 10
        try check(OnboardingValidation.issues(for: .reporting, draft: draft).isEmpty, "Rate alone must allow continuation")
        draft.feeAmount = 25
        try check(OnboardingValidation.issues(for: .reporting, draft: draft).isEmpty, "Both values must allow continuation")
        draft.teamEmails = "valid@example.com, invalid"
        try check(!OnboardingValidation.issues(for: .account, draft: draft).isEmpty, "Invalid team email must be rejected")
        draft.teamEmails = ""
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("crewcrate-checks-\(UUID().uuidString)/draft.json")
        defer { try? FileManager.default.removeItem(at: temp.deletingLastPathComponent()) }
        let store = FileDraftStore(fileURL: temp)
        try await store.save(draft)
        let restored = try await store.load()
        try check(restored == draft, "File storage must round-trip the draft")
        let vm = OnboardingViewModel(store: store)
        await vm.load()
        try check(vm.draft == draft && !vm.hasUnsavedChanges, "View model must restore saved state")
        await vm.prepareReview()
        try check(vm.isPrepared, "Valid setup should prepare locally")
        let resumed = OnboardingViewModel(store: store)
        await resumed.load()
        try check(resumed.isPrepared, "Prepared state must survive relaunch")
        resumed.resumeEditing()
        try check(!resumed.isPrepared && !resumed.draft.confirmsAccuracy, "Editing must require a fresh confirmation")
        let empty = OnboardingViewModel(store: MemoryDraftStore())
        await empty.load(); await empty.next()
        try check(empty.step == .account && !empty.validationMessages.isEmpty, "Invalid setup must not advance")
        let failed = OnboardingViewModel(store: FailingStore())
        await failed.load(); failed.draft = draft; await failed.prepareReview()
        try check(!failed.isPrepared && failed.errorMessage != nil, "A failed save must not look submitted")
        let unreadable = OnboardingViewModel(store: FailingStore(failLoad: true))
        await unreadable.load()
        let saved = await unreadable.save()
        try check(unreadable.loadFailed && !saved, "Unreadable drafts must not be overwritten")
        print("PASS: CSV parsing, validation, persistence, resume, review preparation, and failure handling")
    }
}
