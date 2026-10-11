import Foundation
import Observation

@MainActor @Observable
final class CampaignEditorViewModel {
    var config = CampaignConfig()
    private var detailReview: CampaignConfig?
    private var limitReview: CampaignConfig?
    private var recipientReview: CampaignConfig?
    var detailsConfirmed: Bool {
        get { detailReview == config }
        set { detailReview = newValue ? config : nil }
    }
    var limitsConfirmed: Bool {
        get { limitReview == config }
        set { limitReview = newValue ? config : nil }
    }
    var recipientsConfirmed: Bool {
        get { recipientReview == config }
        set { recipientReview = newValue ? config : nil }
    }
    var reviewsComplete: Bool { detailsConfirmed && limitsConfirmed && recipientsConfirmed }
    func finalize() async {
        guard reviewsComplete else { errorMessage = "Review and confirm the campaign details, limits and recipients first."; return }
        await prepare()
    }
    var aiName: String {
        get { config.aiName ?? "" }
        set { config.aiName = newValue }
    }
    var aiBrief: String {
        get { config.aiBrief ?? "" }
        set { config.aiBrief = newValue }
    }
    private var clockCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: config.timeZone) ?? .current
        return calendar
    }
    private func clockTime(hour: Int, minute: Int) -> Date {
        clockCalendar.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: hour, minute: minute))!
    }
    var startTime: Date {
        get { clockTime(hour: config.startHour, minute: config.startMinute ?? 0) }
        set { config.startHour = clockCalendar.component(.hour, from: newValue); config.startMinute = clockCalendar.component(.minute, from: newValue) }
    }
    var endTime: Date {
        get { clockTime(hour: config.endHour, minute: config.endMinute ?? 0) }
        set { config.endHour = clockCalendar.component(.hour, from: newValue); config.endMinute = clockCalendar.component(.minute, from: newValue) }
    }
    var sendingTimeRange: ClosedRange<Date> { clockTime(hour: 9, minute: 0)...clockTime(hour: 17, minute: 0) }
    var sendingTimeZone: TimeZone { clockCalendar.timeZone }
    private(set) var record: CampaignRecord?
    var selectedImportID: UUID?
    private(set) var handoffEmails: [String] = []
    private(set) var importedFiles: [LeadImportBatch] = []
    private(set) var candidates: [LeadRecord] = []
    private(set) var history: [CampaignActivity] = []
    private(set) var isBusy = false
    private(set) var isLoading = false
    private(set) var moreFiles = false
    var blocksEditing: Bool { isBusy || (isLoading && initialID != nil && record == nil) }
    @ObservationIgnored private let loader: CampaignEditorLoader
    private(set) var errorMessage: String?
    private(set) var notice: String?
    private(set) var candidatesTruncated = false
    private(set) var moreHistory = false
    var controlReason = ""
    let isDemo: Bool
    @ObservationIgnored private let partnerID: UUID
    @ObservationIgnored private let initialID: UUID?
    @ObservationIgnored private let repository: any CampaignRepository
    @ObservationIgnored private let leads: any LeadRepository
    @ObservationIgnored private var savedConfig = CampaignConfig()
    var hasUnsavedChanges: Bool { config != savedConfig }
    init(partnerID: UUID, id: UUID?, repository: any CampaignRepository, leads: any LeadRepository, isDemo: Bool) { self.loader = CampaignEditorLoader(campaigns: repository, leads: leads); self.partnerID = partnerID; initialID = id; self.repository = repository; self.leads = leads; self.isDemo = isDemo }
    func load(discardEdits: Bool = false) async {
        guard !isBusy, !isLoading else { return }
        if hasUnsavedChanges && !discardEdits { errorMessage = "Save your edits or discard them before refreshing."; return }
        isLoading = true; errorMessage = nil; defer { isLoading = false }
        do {
            let result = try await loader.load(partnerID: partnerID, campaignID: record?.id ?? initialID, importID: selectedImportID)
            try Task.checkCancellation()
            handoffEmails = result.emails
            importedFiles = result.files; moreFiles = result.files.count == 50
            candidates = result.leads; candidatesTruncated = result.leads.count == 50
            if let current = result.campaign, !hasUnsavedChanges || discardEdits {
                record = current; config = current.config; savedConfig = current.config
                history = result.history; moreHistory = result.history.count == 50
            }
        } catch is CancellationError { }
        catch { errorMessage = error.localizedDescription }
    }
    func loadMoreFiles() async {
        guard !isBusy, !isLoading else { return }
        isBusy = true; defer { isBusy = false }
        do {
            let page = try await leads.imports(partnerID: partnerID, offset: importedFiles.count)
            importedFiles += page; moreFiles = page.count == 50
        } catch { errorMessage = error.localizedDescription }
    }
    func reloadRecipients() async {
        guard !isBusy, !isLoading else { return }
        isBusy = true; defer { isBusy = false }
        do {
            let page = try await leads.leadsInImport(partnerID: partnerID, importID: selectedImportID, offset: 0)
            candidates = page; candidatesTruncated = page.count == 50
        } catch { errorMessage = error.localizedDescription }
    }
    func contactWorkspace() -> LeadWorkspaceViewModel { LeadWorkspaceViewModel(id: partnerID, repository: leads, isDemo: isDemo) }
    func loadMoreCandidates() async {
        guard !isBusy, !isLoading else { return }
        isBusy = true; defer { isBusy = false }
        do {
            let page = try await leads.leadsInImport(partnerID: partnerID, importID: selectedImportID, offset: candidates.count)
            candidates += page; candidatesTruncated = page.count == 50
        } catch { errorMessage = error.localizedDescription }
    }
    var canChangeRecipients: Bool { !isBusy && !isLoading && record?.status != .paused && record?.status != .archived }
    func selectAllEligibleRecipients() async {
        guard canChangeRecipients else { return }
        isBusy = true; errorMessage = nil; defer { isBusy = false }
        let importID = selectedImportID
        var selected = config.leadIDs
        var known = Set(selected)
        var offset = 0
        do {
            while selected.count < 500 {
                try Task.checkCancellation()
                let page = try await leads.leadsInImport(partnerID: partnerID, importID: importID, offset: offset)
                for lead in page where lead.status == .eligible && lead.smsPermission == "recorded" && !lead.optedOut {
                    if selected.count < 500 && known.insert(lead.id).inserted { selected.append(lead.id) }
                }
                offset += page.count
                if page.count < 50 { break }
            }
            try Task.checkCancellation()
            config.leadIDs = selected
            notice = selected.count == 500 ? "500 recipients selected — the campaign limit. Save your draft to keep this selection." : "\(selected.count) recipients selected. Save your draft to keep this selection."
        } catch is CancellationError { }
        catch { errorMessage = error.localizedDescription }
    }
    func clearRecipients() {
        guard canChangeRecipients else { return }
        config.leadIDs = []
    }
    func toggle(_ lead: LeadRecord) {
        guard canChangeRecipients else { return }
        if config.leadIDs.contains(lead.id) { config.leadIDs.removeAll { $0 == lead.id } }
        else if config.leadIDs.count < 500 && lead.status == .eligible && lead.smsPermission == "recorded" && !lead.optedOut { config.leadIDs.append(lead.id) }
    }
    func useSamplePlan() {
        guard isDemo else { return }
        config.name = "Sample recovery pilot"; config.offer = "Reconnect about your earlier enquiry."
        config.messageTemplate = "Hi, this is the sample business following up on your earlier enquiry. Would you like to talk with our team? Reply STOP to opt out."
        config.qualification = "Interested in the service and ready to speak to sales."; config.handoffEmail = "sales@example.com"
        config.leadIDs = candidates.filter { $0.smsPermission == "recorded" && !$0.optedOut }.prefix(25).map(\.id)
    }
    @discardableResult func save() async -> Bool {
        guard !isBusy, !isLoading else { return false }
        if record != nil && !hasUnsavedChanges { return true }
        isBusy = true; errorMessage = nil; defer { isBusy = false }
        do { let current = try await repository.saveCampaign(partnerID: partnerID, id: record?.id, config: config, expectedRevision: record?.revision); record = current; savedConfig = config; notice = "Campaign draft saved. Nothing was sent."; return true }
        catch { errorMessage = error.localizedDescription; return false }
    }
    func prepare() async {
        guard await save(), let record else { return }
        isBusy = true; errorMessage = nil
        do { self.record = try await repository.prepareCampaign(partnerID: partnerID, id: record.id, expectedRevision: record.revision); notice = "Ready to connect to messaging. No owner campaign approval or message sending occurred." }
        catch { errorMessage = error.localizedDescription }
        isBusy = false
        if errorMessage == nil { await load() }
    }
    func control(_ action: String) async {
        guard !isBusy, let record else { return }
        guard !hasUnsavedChanges else { errorMessage = "Save edits before changing campaign status."; return }
        isBusy = true; errorMessage = nil
        do { self.record = try await repository.controlCampaign(partnerID: partnerID, id: record.id, action: action, reason: controlReason, expectedRevision: record.revision); controlReason = ""; notice = "Campaign status updated. Sending remains disabled." }
        catch { errorMessage = error.localizedDescription }
        isBusy = false
        if errorMessage == nil { await load() }
    }
    func loadMoreHistory() async {
        guard !isBusy, let record else { return }; isBusy = true; defer { isBusy = false }
        do { let page = try await repository.campaignHistory(partnerID: partnerID, id: record.id, offset: history.count); history += page; moreHistory = page.count == 50 } catch { errorMessage = error.localizedDescription }
    }
    func conversations() -> ConversationListViewModel? {
        guard let record else { return nil }
        return ConversationListViewModel(partnerID: partnerID, campaign: record, repository: repository, candidates: candidates, isDemo: isDemo)
    }
}
