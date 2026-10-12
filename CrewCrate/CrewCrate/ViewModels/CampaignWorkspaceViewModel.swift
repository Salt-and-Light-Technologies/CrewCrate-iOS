import Foundation
import Observation

@MainActor
@Observable
final class CampaignWorkspaceViewModel {
    var campaigns: [WorkspaceCampaign] = []
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
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            campaigns = try await service.campaigns(business: business.id)
            hasLoaded = true
            error = nil
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
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
    var canSave: Bool {
        !isBusy && !saveOutcomeUnknown && business.status != "paused" &&
        (original?.isEditable ?? true) && !settings.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        settings.name.count <= 160 && settings.offer.count <= 2000 && settings.qualification.count <= 2000 &&
        (settings.ai_brief?.count ?? 0) <= 10000 && settings.handoff_email.count <= 320 &&
        (upload == nil || (preview != nil && previewMapping == mapping && mapping.isValid))
    }
    var hasEdits: Bool { settings != (original?.config ?? initialSettings) || upload != nil }

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
        mapping = UploadMapping(phone: match(["phone", "phone number", "mobile", "telephone"]),
            name: match(["name", "full name", "contact name"]), email: match(["email", "email address"]),
            sheet: info.selected_sheet ?? "")
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
