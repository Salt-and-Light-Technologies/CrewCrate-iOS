import Foundation
import Observation

typealias OnboardingCompletion = @MainActor () async -> Void

@MainActor @Observable
final class OnboardingViewModel {
    let isLive: Bool
    var draft = OnboardingDraft()
    var feeAmount: Double {
        get { draft.feeAmount ?? 0 }
        set { draft.feeAmount = newValue }
    }
    var feeRate: Double {
        get { draft.feeRate ?? 0 }
        set { draft.feeRate = newValue }
    }
    private(set) var step = OnboardingStep.account
    private(set) var isLoading = true
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private(set) var validationMessages: [String] = []
    private(set) var lastSavedAt: Date?
    private(set) var document: CSVDocument?
    var phoneColumn = 0
    private(set) var loadFailed = false
    @ObservationIgnored private let onSubmitted: OnboardingCompletion?
    @ObservationIgnored private let store: any DraftStore
    @ObservationIgnored private let inspector: any LeadFileInspecting
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var savedDraft: OnboardingDraft?

    init(store: any DraftStore, isLive: Bool = false, onSubmitted: OnboardingCompletion? = nil, inspector: any LeadFileInspecting = LeadFileInspector()) {
        self.onSubmitted = onSubmitted
        self.store = store; self.isLive = isLive; self.inspector = inspector
    }
    var selectedCRM: CRMProvider {
        get { CRMProvider.selection(for: draft.reportingSystem) }
        set { draft.reportingSystem = newValue.storedName }
    }
    var otherCRMName: String {
        get { CRMProvider.customName(from: draft.reportingSystem) }
        set { draft.reportingSystem = "Other: " + newValue }
    }
    var hasUnsavedChanges: Bool { savedDraft != draft }
    var isPrepared: Bool { draft.preparedAt != nil }
    var progress: Double { Double(step.rawValue + 1) / Double(OnboardingStep.allCases.count) }
    var readiness: [(OnboardingStep, Bool)] {
        OnboardingStep.allCases.filter { $0 != .review }.map { ($0, OnboardingValidation.issues(for: $0, draft: draft).isEmpty) }
    }
    func load() async {
        guard !hasLoaded else { return }
        isLoading = true; errorMessage = nil
        do {
            if let loaded = try await store.load() { draft = loaded; step = loaded.savedStep; savedDraft = loaded }
            hasLoaded = true; loadFailed = false
        } catch { loadFailed = true; errorMessage = "Couldn’t restore your draft. \(error.localizedDescription)" }
        isLoading = false
    }
    @discardableResult func save() async -> Bool {
        guard !isBusy, !isLoading, !loadFailed, !(isLive && isPrepared) else { return false }
        isBusy = true; errorMessage = nil
        var snapshot = draft; snapshot.savedStep = step
        defer { isBusy = false }
        do {
            try await store.save(snapshot)
            draft = snapshot; savedDraft = snapshot; lastSavedAt = .now
            return true
        } catch { errorMessage = "Couldn’t save your draft. \(error.localizedDescription)"; return false }
    }
    func next() async {
        validationMessages = OnboardingValidation.issues(for: step, draft: draft)
        guard validationMessages.isEmpty else { return }
        guard await save() else { return }
        if let next = OnboardingStep(rawValue: step.rawValue + 1) { step = next; draft.savedStep = next; _ = await save() }
    }
    func back() async {
        guard await save() else { return }
        if let previous = OnboardingStep(rawValue: step.rawValue - 1) { step = previous; draft.savedStep = previous; validationMessages = []; _ = await save() }
    }
    func edit(_ target: OnboardingStep) async {
        guard await save() else { return }
        step = target; draft.savedStep = target; validationMessages = []; _ = await save()
    }
    func toggleAudience(_ audience: RecoveryAudience) {
        if draft.audience.contains(audience) { draft.audience.removeAll { $0 == audience } }
        else { draft.audience.append(audience) }
    }
    func inspectFile(_ url: URL) async {
        guard !isBusy else { return }
        isBusy = true; errorMessage = nil
        defer { isBusy = false }
        do {
            document = try await inspector.inspect(url)
            phoneColumn = document?.headers.firstIndex(where: { $0.lowercased().contains("phone") || $0.lowercased().contains("mobile") }) ?? 0
        } catch { document = nil; errorMessage = error.localizedDescription }
    }
    func confirmMapping() async {
        guard !isBusy, let document else { return }
        isBusy = true
        do {
            if isLive, let importer = store as? any OnboardingContactImporting {
                draft.importSummary = try await importer.importContacts(document, phoneColumn: phoneColumn)
            } else {
                draft.importSummary = try CSVParser.summarize(document, phoneIndex: phoneColumn)
            }
            self.document = nil
            isBusy = false
            _ = await save()
        } catch { isBusy = false; errorMessage = error.localizedDescription }
    }
    func cancelMapping() { document = nil }
    func reportImportError(_ error: Error) { errorMessage = error.localizedDescription }
    func prepareReview() async {
        validationMessages = OnboardingValidation.allIssues(draft).map { "\($0.0.title): \($0.1)" }
        guard validationMessages.isEmpty else { return }
        if isLive, let server = store as? any ReviewSubmittingStore {
            guard await save() else { return }
            isBusy = true
            defer { isBusy = false }
            do {
                try await server.submit()
                draft.preparedAt = .now; savedDraft = draft
                await onSubmitted?()
            }
            catch { errorMessage = error.localizedDescription }
        } else {
            draft.preparedAt = .now
            if !(await save()) { draft.preparedAt = nil }
        }
    }
    func resumeEditing() { draft.preparedAt = nil; draft.confirmsAccuracy = false; validationMessages = [] }
}
