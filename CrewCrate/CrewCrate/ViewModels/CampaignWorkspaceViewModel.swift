import Foundation
import Observation

@MainActor
@Observable
final class CampaignWorkspaceViewModel {
    var campaigns: [WorkspaceCampaign] = []
    var deletingCampaignID: UUID?
    var isLoading = false
    var hasLoaded = false
    var error: String?
    let business: BusinessSummary
    let service: any CampaignWorkspaceServicing
    let contactService: any WorkspaceContactServicing
    init(business: BusinessSummary, service: any CampaignWorkspaceServicing & WorkspaceContactServicing) {
        self.business = business
        self.service = service
        contactService = service
    }
    func load() async {
        guard !isLoading, deletingCampaignID == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            campaigns = try await service.campaigns(business: business.id)
            hasLoaded = true
            error = nil
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
    func delete(_ campaign: WorkspaceCampaign) async {
        guard !isLoading, deletingCampaignID == nil, !campaign.owner_hold else { return }
        deletingCampaignID = campaign.id
        error = nil
        defer { deletingCampaignID = nil }
        do {
            try await service.deleteCampaign(business: business.id, campaign: campaign.id, revision: campaign.revision)
            campaigns.removeAll { $0.id == campaign.id }
        } catch {
            if let apiError = error as? CrewCrateAPIError {
                self.error = apiError.localizedDescription
            } else {
                self.error = "Couldn’t confirm deletion. Refresh the campaign list before trying again; the campaign may already have been deleted."
            }
        }
    }
    func replace(_ saved: WorkspaceCampaign) {
        campaigns.removeAll { $0.id == saved.id }
        campaigns.insert(saved, at: 0)
    }
}

@MainActor
@Observable
final class CampaignEditorModel {
    var settings: CampaignSettings
    // Draft text preserves incomplete/invalid edits without saving the previous number silently.
    var dailyLimitInput: String? {
        didSet { if let value = Self.planInteger(dailyLimitInput, in: 1...1000) { settings.daily_limit = value } }
    }
    var followUpInput: String? {
        didSet { if let value = Self.planInteger(followUpInput, in: 0...3) { settings.follow_up_limit = value } }
    }
    var step = 0
    var isBusy = false
    var error: String?
    var saveOutcomeUnknown = false
    var upload: ContactUpload?
    var columns: UploadColumns?
    var mapping = UploadMapping()
    var preview: UploadPreview?
    private var previewMapping: UploadMapping?
    let business: BusinessSummary
    private(set) var original: WorkspaceCampaign?
    private let service: any CampaignWorkspaceServicing
    private let reader: any ContactUploadReading
    private let initialSettings: CampaignSettings

    init(business: BusinessSummary, original: WorkspaceCampaign? = nil,
         service: any CampaignWorkspaceServicing, reader: any ContactUploadReading = ContactUploadReader()) {
        self.business = business
        self.original = original
        self.service = service
        self.reader = reader
        var startingSettings = original?.config ?? CampaignSettings()
        if original == nil, let zone = business.onboarding?.time_zone, !zone.isEmpty {
            startingSettings.time_zone = zone
        }
        settings = startingSettings
        initialSettings = startingSettings
    }
    // ai_name is the existing sole wire identity; no separate name override exists.
    var designatedAIName: String {
        get {
            let name = settings.ai_name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? "AI Assistant" : name
        }
        set { settings.ai_name = newValue }
    }
    var canSave: Bool {
        !isBusy && !saveOutcomeUnknown && business.status != "paused" &&
        (original?.isEditable ?? true) && sendingPlanError == nil && !settings.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        settings.name.count <= 160 && settings.offer.count <= 2000 && settings.qualification.count <= 2000 &&
        (settings.ai_name?.count ?? 0) <= 100 &&
        (settings.ai_brief?.count ?? 0) <= 10000 && settings.handoff_email.count <= 320 &&
        (upload == nil || (preview != nil && previewMapping == mapping && mapping.isValid))
    }
    var hasEdits: Bool {
        settings != (original?.config ?? initialSettings) || upload != nil ||
        dailyLimitInput != nil || followUpInput != nil
    }

    private static func planInteger(_ text: String?, in range: ClosedRange<Int>) -> Int? {
        guard let text, !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int(text), range.contains(value) else { return nil }
        return value
    }
    var sendingPlanError: String? {
        if (settings.start_date == nil) != (settings.end_date == nil) {
            return "Choose both a start date and an end date."
        }
        if let start = settings.start_date, let end = settings.end_date,
           start > end { return "Start date must be on or before end date." }
        if !(1...1000).contains(settings.daily_limit) ||
            (dailyLimitInput != nil && Self.planInteger(dailyLimitInput, in: 1...1000) == nil) {
            return "Enter 1–1000 leads per day."
        }
        if followUpInput != nil && Self.planInteger(followUpInput, in: 0...3) == nil {
            return "Enter a follow-up limit from 0 to 3."
        }
        let start = settings.start_hour * 60 + (settings.start_minute ?? 0)
        let end = settings.end_hour * 60 + (settings.end_minute ?? 0)
        if start < 540 || end > 1020 || start >= end {
            return "Choose a start before the end, between 9 AM and 5 PM in the selected time zone."
        }
        return nil
    }

    // These dates represent wall-clock picker values, not scheduled instants. Using a
    // fixed UTC day avoids device/partner time-zone shifts and daylight-saving gaps.
    var sendingPlanCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
    var hasDateRange: Bool { settings.start_date != nil || settings.end_date != nil }
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = sendingPlanCalendar
        formatter.timeZone = sendingPlanCalendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
    private var businessToday: Date {
        let formatter = dateFormatter
        formatter.timeZone = TimeZone(identifier: settings.time_zone) ?? sendingPlanCalendar.timeZone
        return dateFormatter.date(from: formatter.string(from: Date()))!
    }
    func campaignDate(isStart: Bool) -> Date {
        let text = isStart ? settings.start_date : settings.end_date
        return text.flatMap { dateFormatter.date(from: $0) } ?? businessToday
    }
    func setDateRangeEnabled(_ enabled: Bool) {
        if enabled {
            let start = businessToday
            settings.start_date = dateFormatter.string(from: start)
            settings.end_date = dateFormatter.string(from: sendingPlanCalendar.date(byAdding: .day, value: 7, to: start)!)
        } else { settings.start_date = nil; settings.end_date = nil }
    }
    func setCampaignDate(_ date: Date, isStart: Bool) {
        if !hasDateRange { setDateRangeEnabled(true) }
        if isStart { settings.start_date = dateFormatter.string(from: date) }
        else { settings.end_date = dateFormatter.string(from: date) }
    }

    private func clockDate(hour: Int, minute: Int) -> Date {
        sendingPlanCalendar.date(from: DateComponents(year: 2001, month: 1, day: 1,
                                                      hour: hour, minute: minute))!
    }
    var sendingTimeRange: ClosedRange<Date> { clockDate(hour: 9, minute: 0)...clockDate(hour: 17, minute: 0) }
    func sendingTime(isStart: Bool) -> Date {
        clockDate(hour: isStart ? settings.start_hour : settings.end_hour,
                  minute: (isStart ? settings.start_minute : settings.end_minute) ?? 0)
    }
    func setSendingTime(_ date: Date, isStart: Bool) {
        let parts = sendingPlanCalendar.dateComponents([.hour, .minute], from: date)
        guard let hour = parts.hour, let minute = parts.minute else { return }
        if isStart { settings.start_hour = hour; settings.start_minute = minute }
        else { settings.end_hour = hour; settings.end_minute = minute }
    }

    func selectFile(_ url: URL) async {
        guard !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        // Invalidate previous staged import before reading another file.
        upload = nil; columns = nil; mapping = UploadMapping(); invalidatePreview()
        do {
            let file = try await reader.read(url)
            let info = try await service.columns(business: business.id, upload: file, sheet: "")
            upload = file
            applyColumns(info)
        } catch { self.error = error.localizedDescription }
    }
    func selectSheet(_ sheet: String) async {
        guard !isBusy, let upload else { return }
        isBusy = true
        error = nil
        invalidatePreview()
        defer { isBusy = false }
        do { applyColumns(try await service.columns(business: business.id, upload: upload, sheet: sheet)) }
        catch { self.error = error.localizedDescription }
    }
    private func applyColumns(_ info: UploadColumns) {
        columns = info
        func match(_ names: [String]) -> String {
            info.columns.first { names.contains($0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)) } ?? ""
        }
        func uniqueMatch(_ names: [String]) -> String {
            let matches = info.columns.filter { names.contains($0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)) }
            return matches.count == 1 ? matches[0] : ""
        }
        mapping = UploadMapping(phone: match(["phone", "phone number", "mobile", "telephone"]),
            name: match(["name", "full name", "contact name"]), email: match(["email", "email address"]),
            sheet: info.selected_sheet ?? "",
            permission: uniqueMatch(["sms permission", "sms_permission", "permission", "sms consent"]),
            evidence: uniqueMatch(["permission evidence", "permission_evidence", "consent evidence", "evidence"]),
            optout: uniqueMatch(["opted out", "opted_out", "optout", "opt out", "sms opt out"]))
    }
    func invalidatePreview() { preview = nil; previewMapping = nil }
    func removeUpload() {
        guard !isBusy else { return }
        upload = nil; columns = nil; mapping = UploadMapping(); invalidatePreview()
    }
    func previewUpload() async {
        guard !isBusy, let upload, mapping.isValid else { return }
        isBusy = true
        error = nil
        invalidatePreview()
        let selectedMapping = mapping
        defer { isBusy = false }
        do {
            let result = try await service.preview(business: business.id, upload: upload, mapping: selectedMapping)
            if selectedMapping == mapping { preview = result; previewMapping = selectedMapping }
        } catch { self.error = error.localizedDescription }
    }
    func save() async -> WorkspaceCampaign? {
        guard canSave else { return nil }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            let result: WorkspaceCampaign
            if let upload, let preview {
                result = try await service.saveUpload(business: business.id, original: original, settings: settings,
                    upload: upload, mapping: mapping, preview: preview)
            } else {
                result = try await service.saveCampaign(business: business.id, original: original, settings: settings)
            }
            original = result
            settings = result.config
            dailyLimitInput = nil; followUpInput = nil
            removeStagedUploadAfterSave()
            return result
        } catch {
            self.error = error.localizedDescription
            // Never blindly replay a creation/import after an uncertain response.
            let status = (error as? CrewCrateAPIError)?.status
            if status == nil || (status ?? 500) >= 500 {
                saveOutcomeUnknown = true
                self.error = "The save result is uncertain. Check your campaign list before trying again; it may already have saved. Your edits are still here."
            }
            return nil
        }
    }
    private func removeStagedUploadAfterSave() {
        upload = nil; columns = nil; invalidatePreview()
    }
    func reloadSaved() async {
        guard !isBusy, let original else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let current = try await service.campaign(business: business.id, id: original.id)
            self.original = current
            settings = current.config
            dailyLimitInput = nil; followUpInput = nil
            removeStagedUploadAfterSave()
            saveOutcomeUnknown = false
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}

@MainActor
@Observable
final class PracticeConversationModel {
    var conversation: PracticeConversation?
    var replyText = ""
    var isBusy = false
    var error: String?
    private struct PendingTurn {
        let id: UUID
        let text: String
        let revision: Int
    }
    private var pending: PendingTurn?
    let business: UUID
    let settings: CampaignSettings
    private let service: any CampaignWorkspaceServicing
    init(business: UUID, settings: CampaignSettings, service: any CampaignWorkspaceServicing) {
        self.business = business
        self.settings = settings
        self.service = service
    }
    var needsRetry: Bool { pending != nil }
    var canReply: Bool { conversation?.status == "active" && !isBusy }
    func start() async {
        guard !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            conversation = try await service.startPractice(business: business, settings: settings)
            pending = nil
            replyText = ""
        } catch { self.error = error.localizedDescription }
    }
    func send() async {
        guard canReply, let conversation else { return }
        let text = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if pending == nil {
            guard !text.isEmpty, text.count <= 2000 else { return }
            pending = PendingTurn(id: UUID(), text: text, revision: conversation.revision)
        }
        guard let pending else { return }
        isBusy = true
        error = nil
        defer { isBusy = false }
        do {
            self.conversation = try await service.reply(business: business, conversation: conversation.id,
                revision: pending.revision, request: pending.id, text: pending.text)
            self.pending = nil
            replyText = ""
        } catch { self.error = error.localizedDescription }
    }
    func refresh() async {
        guard !isBusy, let conversation else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let current = try await service.practice(business: business, id: conversation.id)
            self.conversation = current
            if let pending, current.revision > pending.revision {
                self.pending = nil
                if current.messages.contains(where: { $0.request_id == pending.id }) { replyText = "" }
            }
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
