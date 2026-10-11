import Foundation
import Observation

@MainActor
@Observable
final class CampaignDetailsViewModel {
    var details = CampaignDetails()
    var showsFilePicker = false
    var contactFile: ContactFile?
    var columns: ImportColumns?
    var mapping = ContactMapping() { didSet { preview = nil } }
    var preview: ContactPreview?
    var isImporting = false

    var showsAITest = false
    var workspaceID: UUID?
    var isSaving = false
    var notice: String?
    var savedCampaign: CampaignSummary?
    private var existing: CampaignSummary?
    private var original: CampaignDetails
    var isEditing: Bool { existing != nil }
    let service: any CampaignServicing
    let workspaces: [CampaignWorkspace]
    init(service: any CampaignServicing, workspaces: [CampaignWorkspace]) {
        self.service = service; self.workspaces = workspaces
        existing = nil; original = CampaignDetails()
        workspaceID = workspaces.first(where: { $0.status != "paused" })?.id
    }
    init(service: any CampaignServicing, campaign: CampaignSummary) {
        self.service = service; workspaces = []
        existing = campaign; original = campaign.config
        details = campaign.config; workspaceID = campaign.partnerID
    }
    var timeZones: [String] { Array(Set(TimeZone.knownTimeZoneIdentifiers + [details.timeZone])).sorted() }
    var sendingTimes: [Int] {
        Array(Set(Array(stride(from: 9 * 60, through: 17 * 60, by: 15)) + [startTime, endTime])).sorted()
    }
    var startTime: Int {
        get { details.startHour * 60 + (details.startMinute ?? 0) }
        set { details.startHour = newValue / 60; details.startMinute = newValue % 60 }
    }
    var endTime: Int {
        get { details.endHour * 60 + (details.endMinute ?? 0) }
        set { details.endHour = newValue / 60; details.endMinute = newValue % 60 }
    }
    func timeLabel(_ minutes: Int) -> String {
        let hour = minutes / 60
        return String(format: "%d:%02d %@", hour % 12 == 0 ? 12 : hour % 12, minutes % 60, hour < 12 ? "AM" : "PM")
    }
    var dailyLimitText: String {
        get { details.dailyLimit == 0 ? "" : String(details.dailyLimit) }
        set { details.dailyLimit = Int(newValue.trimmingCharacters(in: .whitespaces)) ?? 0 }
    }
    var settingsError: String? {
        if details.dailyLimit < 1 { return "Enter a daily message limit of at least 1." }
        if startTime < 540 || endTime > 1020 || startTime >= endTime { return "Choose a sending window between 9:00 AM and 5:00 PM, with the end after the start." }
        return nil
    }
    var hasEdits: Bool { details != original || contactFile != nil }
    var saveBlocker: String? {
        if workspaceID == nil { return "Choose a business workspace before saving." }
        if details.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Enter a campaign name before saving." }
        if let settingsError { return settingsError }
        if contactFile != nil && mapping.phone.isEmpty { return "Choose the phone column for the uploaded file before saving." }
        if contactFile != nil && preview == nil { return "Preview the uploaded leads before saving, or remove the selected file to save only campaign changes." }
        return nil
    }
    var canSave: Bool { !isSaving && !isImporting && saveBlocker == nil }
    func clearImport() {
        contactFile = nil; columns = nil; preview = nil; mapping = ContactMapping()
    }
    func chooseFile(_ result: Result<URL, Error>) async {
        guard !isImporting, let workspaceID else { return }
        isImporting = true; notice = nil
        defer { isImporting = false }
        do {
            let file = try await ContactFileReader.read(result.get())
            let info = try await service.contactColumns(partnerID: workspaceID, file: file, sheet: "")
            contactFile = file; columns = info
            mapping = suggestedMapping(info)
        } catch { notice = error.localizedDescription }
    }
    private func suggestedMapping(_ info: ImportColumns) -> ContactMapping {
        func match(_ aliases: [String]) -> String {
            info.columns.first { aliases.contains($0.lowercased().replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces)) } ?? ""
        }
        return ContactMapping(phone: match(["phone", "phone number", "mobile", "mobile phone", "telephone"]),
                              name: match(["name", "full name", "contact name"]), email: match(["email", "email address"]),
                              sheet: info.selected_sheet ?? "")
    }
    func changeSheet(_ sheet: String) async {
        guard !isImporting, let file = contactFile, let workspaceID else { return }
        isImporting = true; preview = nil
        defer { isImporting = false }
        do {
            let info = try await service.contactColumns(partnerID: workspaceID, file: file, sheet: sheet)
            columns = info; mapping = suggestedMapping(info)
        } catch { notice = error.localizedDescription }
    }
    func previewFile() async {
        guard !isImporting, let file = contactFile, let workspaceID, !mapping.phone.isEmpty else { return }
        isImporting = true; preview = nil; notice = nil
        defer { isImporting = false }
        do {
            let result = try await service.previewContacts(partnerID: workspaceID, file: file, mapping: mapping)
            if result.imported + result.duplicates == 0 { notice = "No valid leads found. Check your phone column and file." }
            else { preview = result }
        } catch { notice = error.localizedDescription }
    }
    func reloadSaved() async {
        guard !isSaving, let existing else { return }
        isSaving = true; notice = nil
        defer { isSaving = false }
        do {
            let value = try await service.campaign(partnerID: existing.partnerID, campaignID: existing.id)
            self.existing = value; original = value.config; details = value.config
            clearImport()
        } catch { notice = error.localizedDescription }
    }
    func save() async -> Bool {
        guard !isSaving && !isImporting else { return false }
        if let blocker = saveBlocker { notice = blocker; return false }
        guard let workspaceID else { return false }
        isSaving = true; defer { isSaving = false }
        do {
            details.name = details.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let file = contactFile, let preview {
                savedCampaign = try await service.saveCampaignWithContacts(partnerID: workspaceID, campaignID: existing?.id,
                    revision: existing?.revision, details: details, file: file, mapping: mapping, partnerRevision: preview.partner_revision)
            } else if let existing {
                savedCampaign = try await service.updateCampaign(partnerID: workspaceID, campaignID: existing.id, revision: existing.revision, details: details)
            } else {
                savedCampaign = try await service.createCampaign(partnerID: workspaceID, details: details)
            }
            return true
        } catch { notice = error.localizedDescription; return false }
    }
}
