import SwiftUI
import UniformTypeIdentifiers

struct CampaignWorkspaceView: View {
    @State private var model: CampaignWorkspaceViewModel
    @State private var creatingCampaign = false
    @State private var campaignToDelete: WorkspaceCampaign?
    @State private var confirmingDeletion = false
    init(business: BusinessSummary, service: any CampaignWorkspaceServicing & WorkspaceContactServicing) {
        _model = State(initialValue: CampaignWorkspaceViewModel(business: business, service: service))
    }
    var body: some View {
        List {
            Section {
                Text(model.business.name).font(.title2.bold())
                Text("Turn old leads into new conversations.").foregroundStyle(.secondary)
                Text("Create an offer, try your assistant, then add contacts.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                Button { creatingCampaign = true } label: {
                    Label("Create a campaign", systemImage: "plus").frame(maxWidth: .infinity)
                }
                .buttonStyle(AuthenticationButtonStyle())
                .disabled(model.business.status == "paused" || model.deletingCampaignID != nil)
            }
            Section("Your campaigns") {
                if model.deletingCampaignID != nil { ProgressView("Deleting campaign…") }
                if model.isLoading && !model.hasLoaded { ProgressView("Loading campaigns…") }
                if model.hasLoaded && model.campaigns.isEmpty {
                    Text("Start with one offer. Your saved campaigns will appear here.").foregroundStyle(.secondary)
                }
                ForEach(model.campaigns) { campaign in
                    NavigationLink {
                        CampaignOverviewView(campaign: campaign, business: model.business,
                            service: model.service, contactService: model.contactService, onSave: model.replace)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(campaign.config.name).font(.headline)
                            Text(campaign.config.offer.isEmpty ? "Add an offer" : campaign.config.offer)
                                .font(.subheadline).lineLimit(2).foregroundStyle(.secondary)
                            HStack {
                                Text(campaign.statusTitle)
                                Spacer()
                                Text("\(campaign.config.lead_ids.count) contacts")
                            }.font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 8)
                    }
                    .disabled(model.deletingCampaignID != nil)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !campaign.owner_hold {
                            Button(role: .destructive) {
                                campaignToDelete = campaign; confirmingDeletion = true
                            } label: { Label("Delete", systemImage: "trash") }
                            .disabled(model.isLoading || model.deletingCampaignID != nil)
                        }
                    }
                    .contextMenu {
                        if !campaign.owner_hold {
                            Button(role: .destructive) {
                                campaignToDelete = campaign; confirmingDeletion = true
                            } label: { Label("Delete campaign", systemImage: "trash") }
                            .disabled(model.isLoading || model.deletingCampaignID != nil)
                        }
                    }
                }
                if let error = model.error {
                    Text(error).foregroundStyle(.red)
                    Button("Try again") { Task { await model.load() } }
                }
            }
            Section {
                Label("Real texting is not connected yet", systemImage: "info.circle")
                    .font(.subheadline)
                Text("You can save drafts and practice. No customers are contacted.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .confirmationDialog("Delete \(campaignToDelete?.config.name ?? "campaign")?",
                            isPresented: $confirmingDeletion, titleVisibility: .visible) {
            if let campaign = campaignToDelete {
                Button("Delete campaign", role: .destructive) {
                    Task { await model.delete(campaign) }
                    campaignToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { campaignToDelete = nil }
        } message: {
            Text("This permanently deletes the campaign, its tracking history and saved practice conversations. Business contacts, permission records and opt-outs are kept.")
        }
        .navigationTitle("Campaigns")
        .task { await model.load() }
        .refreshable { await model.load() }
        .sheet(isPresented: $creatingCampaign, onDismiss: { Task { await model.load() } }) {
            NavigationStack {
                CampaignEditorView(business: model.business, service: model.service, onSave: model.replace)
            }
        }
    }
}

private struct CampaignOverviewView: View {
    @State private var campaign: WorkspaceCampaign
    @State private var editing = false
    let business: BusinessSummary
    let service: any CampaignWorkspaceServicing
    let contactService: any WorkspaceContactServicing
    let onSave: (WorkspaceCampaign) -> Void
    init(campaign: WorkspaceCampaign, business: BusinessSummary,
         service: any CampaignWorkspaceServicing, contactService: any WorkspaceContactServicing,
         onSave: @escaping (WorkspaceCampaign) -> Void) {
        _campaign = State(initialValue: campaign)
        self.business = business; self.service = service; self.onSave = onSave
        self.contactService = contactService
    }
    var body: some View {
        List {
            Section {
                Text(campaign.config.name).font(.title2.bold())
                Text(campaign.statusTitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Section("The offer") {
                Text(campaign.config.offer.isEmpty ? "No offer added yet" : campaign.config.offer)
                LabeledContent("Assistant", value: campaign.config.ai_name ?? "Assistant")
                LabeledContent("Contacts", value: String(campaign.config.lead_ids.count))
            }
            Section {
                NavigationLink {
                    WorkspaceContactView(business: business.id, campaign: campaign.id,
                        readOnly: !campaign.isEditable || business.status == "paused", service: contactService)
                } label: { Label("Review campaign contacts", systemImage: "person.2") }
                NavigationLink {
                    PracticeConversationView(business: business.id, settings: campaign.config, service: service)
                } label: { Label("Try your assistant", systemImage: "bubble.left.and.bubble.right") }
                Button { editing = true } label: { Label("Edit campaign or add contacts", systemImage: "pencil") }
                    .disabled(!campaign.isEditable || business.status == "paused")
            }
            Section("Before real outreach") {
                Label("SMS and registry screening are not connected", systemImage: "exclamationmark.circle")
                if campaign.blockers.isEmpty {
                    Text("Plan checks are clear. Provider setup is still required before sending.")
                } else {
                    DisclosureGroup("Review \(campaign.blockers.count) plan requirements") {
                        ForEach(Array(campaign.blockers.enumerated()), id: \.offset) { _, blocker in
                            Text(blocker).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Campaign")
        .sheet(isPresented: $editing) {
            NavigationStack {
                CampaignEditorView(business: business, original: campaign, service: service) { saved in
                    campaign = saved
                    onSave(saved)
                }
            }
        }
    }
}

struct CampaignEditorView: View {
    private enum SendingPlanField: Hashable { case dailyLimit, followUp }
    @FocusState private var sendingPlanFocus: SendingPlanField?
    @State private var model: CampaignEditorModel
    @State private var eligiblePreviewOnly = true
    @State private var importing = false
    @State private var discarding = false
    @State private var reloading = false
    @Environment(\.dismiss) private var dismiss
    private let service: any CampaignWorkspaceServicing
    private let onSave: (WorkspaceCampaign) -> Void
    init(business: BusinessSummary, original: WorkspaceCampaign? = nil,
         service: any CampaignWorkspaceServicing, onSave: @escaping (WorkspaceCampaign) -> Void) {
        _model = State(initialValue: CampaignEditorModel(business: business, original: original, service: service))
        self.service = service; self.onSave = onSave
    }
    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Step \(model.step + 1) of 3").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                ProgressView(value: Double(model.step + 1), total: 3).tint(AuthenticationStyle.purple)
            }.padding(.horizontal, 20).padding(.vertical, 12)
            Form {
                switch model.step {
                case 0: offerFields
                case 1: assistantFields
                default: uploadFields
                }
                if let error = model.error {
                    Section {
                        Text(error).foregroundStyle(.red)
                        if model.original != nil {
                            Button("Reload saved campaign and discard edits") { reloading = true }
                        }
                    }
                }
            }.disabled(model.isBusy)
            HStack(spacing: 16) {
                if model.step > 0 {
                    Button("Back") { model.step -= 1 }.frame(minHeight: 44)
                }
                if model.step < 2 {
                    Button("Continue") { model.step += 1 }
                        .buttonStyle(AuthenticationButtonStyle())
                        .disabled(model.settings.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  (model.step == 1 && model.sendingPlanError != nil))
                } else {
                    Button {
                        Task { if let saved = await model.save() { onSave(saved); dismiss() } }
                    } label: {
                        if model.isBusy { ProgressView("Saving…").frame(maxWidth: .infinity) }
                        else { Text("Save draft") }
                    }
                    .buttonStyle(AuthenticationButtonStyle()).disabled(!model.canSave)
                }
            }.padding(20).disabled(model.isBusy)
        }
        .navigationTitle(model.original == nil ? "New campaign" : "Edit campaign")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { if model.hasEdits { discarding = true } else { dismiss() } }
                    .disabled(model.isBusy)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { sendingPlanFocus = nil }
            }
        }
        .interactiveDismissDisabled(model.hasEdits || model.isBusy)
        .confirmationDialog("Discard unsaved changes?", isPresented: $discarding, titleVisibility: .visible) {
            Button("Discard and close", role: .destructive) { dismiss() }
        }
        .confirmationDialog("Reloading will discard your edits and staged upload.", isPresented: $reloading, titleVisibility: .visible) {
            Button("Reload saved campaign", role: .destructive) { Task { await model.reloadSaved() } }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [
            .commaSeparatedText, .tabSeparatedText, UTType(filenameExtension: "xlsx") ?? .data
        ]) { result in
            switch result {
            case .success(let url): Task { await model.selectFile(url) }
            case .failure(let error): model.error = error.localizedDescription
            }
        }
        .onChange(of: model.mapping) { _, _ in model.invalidatePreview() }
    }

    private var offerFields: some View {
        @Bindable var model = model
        return Group {
            Section {
                Text("What will you offer?").font(.title2.bold())
                Text("Choose one clear reason for an old lead to reconnect.").foregroundStyle(.secondary)
            }
            Section("Campaign details") {
                TextField("Campaign name, e.g. Spring roof inspections", text: $model.settings.name)
                TextField("Your offer", text: $model.settings.offer, axis: .vertical).lineLimit(3...6)
                TextField("Additional strong-response signal (optional)", text: $model.settings.qualification, axis: .vertical)
                    .lineLimit(2...5)
                Text("Qualified leads can reach your team without this signal. If they also meet it, your team sees a strong response with the supporting evidence.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Every campaign includes built-in AI behavior for your business. Your assistant identifies itself as AI.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Business contact") {
                TextField("Contact email", text: $model.settings.handoff_email)
                    .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                Text("Stored for campaign planning. This version does not send handoff emails.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
    private var assistantFields: some View {
        @Bindable var model = model
        return Group {
            Section {
                Text("Meet your assistant").font(.title2.bold())
                Text("Choose a name and a writing style that fits your business.").foregroundStyle(.secondary)
            }
            Section("Designated AI") {
                Picker("Designated AI", selection: Binding(
                    get: { model.designatedAIName }, set: { model.designatedAIName = $0 })) {
                    ForEach(["Emma", "Olivia", "Sophia", "Ava", "Mia", "Liam", "Noah", "James", "Ethan", "Lucas"], id: \.self) { Text($0) }
                    if !["Emma", "Olivia", "Sophia", "Ava", "Mia", "Liam", "Noah", "James", "Ethan", "Lucas"].contains(model.designatedAIName) {
                        Text(model.designatedAIName == "AI Assistant" ? "AI Assistant" : model.designatedAIName + " (saved)")
                            .tag(model.designatedAIName)
                    }
                }
            }
            Section {
                Text("The selected name is used by your business’s AI assistant. It always identifies itself as AI.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Tone and instructions") {
                TextField("Describe how your assistant should write", text: Binding(
                    get: { model.settings.ai_brief ?? "" }, set: { model.settings.ai_brief = $0 }), axis: .vertical)
                    .lineLimit(4...8)
                Menu("Use a style preset") {
                    Button("Warm and professional") { model.settings.ai_brief = "Use a warm, professional tone. Keep messages short and clear." }
                    Button("Friendly and casual") { model.settings.ai_brief = "Use a friendly, casual tone. Be respectful, concise and easy to understand." }
                    Button("Formal and direct") { model.settings.ai_brief = "Use a formal, direct tone. Avoid jargon and keep messages concise." }
                }
            }
            Section {
                NavigationLink {
                    PracticeConversationView(business: model.business.id, settings: model.settings, service: service)
                } label: { Label("Try these settings", systemImage: "bubble.left.and.bubble.right") }
                Text("You play the lead. No texts, real appointments or worker alerts are sent.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Optional sending plan") {
                DisclosureGroup("Timing and limits") {
                    Toggle("Use a date range", isOn: Binding(
                        get: { model.hasDateRange }, set: { model.setDateRangeEnabled($0) }))
                    DatePicker("Start date", selection: Binding(
                        get: { model.campaignDate(isStart: true) },
                        set: { model.setCampaignDate($0, isStart: true) }), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.timeZone, model.sendingPlanCalendar.timeZone)
                        .disabled(!model.hasDateRange)
                    DatePicker("End date", selection: Binding(
                        get: { model.campaignDate(isStart: false) },
                        set: { model.setCampaignDate($0, isStart: false) }), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.timeZone, model.sendingPlanCalendar.timeZone)
                        .disabled(!model.hasDateRange)
                    BusinessTimeZonePicker(selection: $model.settings.time_zone)
                    Text(model.hasDateRange
                         ? "Both dates are included, in the business time zone. Outreach and follow-ups must stop outside this period. Daily sending is not connected yet."
                         : "No date restriction is saved. Enable a date range to limit the campaign period.")
                        .font(.footnote).foregroundStyle(.secondary)
                    DatePicker("Sending starts", selection: Binding(
                        get: { model.sendingTime(isStart: true) },
                        set: { model.setSendingTime($0, isStart: true) }),
                        in: model.sendingTimeRange, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .environment(\.timeZone, model.sendingPlanCalendar.timeZone)
                    DatePicker("Sending ends", selection: Binding(
                        get: { model.sendingTime(isStart: false) },
                        set: { model.setSendingTime($0, isStart: false) }),
                        in: model.sendingTimeRange, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .environment(\.timeZone, model.sendingPlanCalendar.timeZone)
                    Text("Times use the selected time zone. Choose a window between 9 AM and 5 PM.")
                        .font(.footnote).foregroundStyle(.secondary)
                    LabeledContent("Leads contacted") {
                        TextField("1–1000", text: Binding(
                            get: { model.dailyLimitInput ?? String(model.settings.daily_limit) },
                            set: { model.dailyLimitInput = $0 }))
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .frame(minWidth: 60)
                            .accessibilityLabel("Leads contacted")
                            .focused($sendingPlanFocus, equals: .dailyLimit)
                    }
                    Text("The planned daily outreach limit, not a repeat-contact count for one lead. Enter 1–1000.")
                        .font(.footnote).foregroundStyle(.secondary)
                    LabeledContent {
                        TextField("0–3", text: Binding(
                            get: { model.followUpInput ?? String(model.settings.follow_up_limit) },
                            set: { model.followUpInput = $0 }))
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            .frame(minWidth: 60)
                            .accessibilityLabel("Planned follow-up")
                            .focused($sendingPlanFocus, equals: .followUp)
                    } label: {
                        Text("Planned follow-up")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Enter 0–3 planned follow-ups. The plan stores this limit only; follow-up timing and per-lead versus campaign-wide counting are not yet defined.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let error = model.sendingPlanError {
                        Text(error).foregroundStyle(.red)
                    }
                    Text("These settings save a plan. No sending scheduler is connected yet.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
    private var uploadFields: some View {
        @Bindable var model = model
        return Group {
            Section {
                Text("Add your contacts").font(.title2.bold())
                Text("Upload now, or save your draft and add contacts later.").foregroundStyle(.secondary)
                Button { importing = true } label: { Label("Choose a spreadsheet", systemImage: "doc.badge.plus") }
                Text("CSV, TSV or Excel .xlsx · up to 5 MB. Export Google Sheets or Numbers first.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let upload = model.upload, let info = model.columns {
                Section(upload.filename) {
                    if info.sheets.count > 1 {
                        Picker("Worksheet", selection: Binding(get: { model.mapping.sheet }, set: { sheet in
                            Task { await model.selectSheet(sheet) }
                        })) { ForEach(info.sheets, id: \.self) { Text($0).tag($0) } }
                    }
                    columnPicker("Phone (required)", selected: $model.mapping.phone, columns: info.columns)
                    columnPicker("Name (optional)", selected: $model.mapping.name, columns: info.columns)
                    columnPicker("Email (optional)", selected: $model.mapping.email, columns: info.columns)
                    columnPicker("SMS permission", selected: $model.mapping.permission, columns: info.columns)
                    columnPicker("Permission evidence", selected: $model.mapping.evidence, columns: info.columns)
                    columnPicker("Opted out", selected: $model.mapping.optout, columns: info.columns)
                    Toggle("I reviewed permission for this business’s marketing texts", isOn: $model.mapping.permissionAttested)
                    Text("SMS permission: recorded, yes or true needs evidence of at least 8 characters and your review confirmation. Unknown or blank is not consent; revoked, no, false, opted_out or opt-out blocks texts. Opted out: true, yes or 1 blocks texts; false, no, 0 or blank does not grant consent. Other values must be corrected before import.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Preview contacts") { Task { await model.previewUpload() } }
                        .disabled(!model.mapping.isValid)
                    Button("Remove staged file", role: .destructive) { model.removeUpload() }
                }
            }
            if let preview = model.preview {
                Section("File preview") {
                    LabeledContent("New contacts", value: String(preview.imported))
                    LabeledContent("Duplicates", value: String(preview.duplicates))
                    LabeledContent("Invalid rows", value: String(preview.invalid))
                    if let eligible = preview.eligible_count, let excluded = preview.excluded_count {
                        LabeledContent("Eligible contacts", value: String(eligible))
                        LabeledContent("Excluded contacts", value: String(excluded))
                        Toggle("Show eligible contacts only", isOn: $eligiblePreviewOnly)
                        ForEach((preview.contacts ?? []).filter { !eligiblePreviewOnly || $0.eligible_for_sms }) { contact in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.name.isEmpty ? contact.phone : contact.name).font(.headline)
                                Text("Row \(contact.row_number) · \(contact.phone)").font(.footnote)
                                LabeledContent("SMS permission", value: contact.sms_permission)
                                LabeledContent("Opted out", value: contact.opted_out ? "Yes" : "No")
                                ForEach(contact.exclusion_reasons, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
                            }
                        }
                        if preview.contacts_truncated == true {
                            Text("Showing up to 100 eligible and 100 excluded contacts. Counts cover the full file.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Text("This filter changes the preview only. All valid contacts and preferences are saved for review. Only eligible contacts become campaign recipients; changing this display filter never selects excluded contacts.")
                            .font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text("Eligibility preview needs the updated backend. Missing permission does not allow texts.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    if !preview.issues.isEmpty {
                        DisclosureGroup("Review row issues") {
                            ForEach(Array(preview.issues.enumerated()), id: \.offset) { _, issue in
                                Text("Row \(issue.row_number): \(issue.detail)").font(.footnote)
                            }
                            if preview.issues_truncated { Text("More issues exist than this preview can show.").font(.footnote) }
                        }
                    }
                }
            }
            Section {
                Text("Saving imports valid contacts and skips invalid rows. Existing contacts and opt-outs are preserved. Uploading does not establish SMS permission or complete a Do Not Call check.")
                    .font(.footnote).foregroundStyle(.secondary)
                if !model.settings.lead_ids.isEmpty {
                    Text("\(model.settings.lead_ids.count) saved contacts remain attached to this campaign.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
    private func columnPicker(_ title: String, selected: Binding<String>, columns: [String]) -> some View {
        Picker(title, selection: selected) {
            Text("Not selected").tag("")
            ForEach(columns, id: \.self) { Text($0).tag($0) }
        }
    }
}

struct PracticeConversationView: View {
    @State private var model: PracticeConversationModel
    @State private var restarting = false
    init(business: UUID, settings: CampaignSettings, service: any CampaignWorkspaceServicing) {
        _model = State(initialValue: PracticeConversationModel(business: business, settings: settings, service: service))
    }
    var body: some View {
        @Bindable var model = model
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Practice only").font(.headline).foregroundStyle(AuthenticationStyle.purple)
                    Text("Reply as a fictional lead. Try an offer question, a request for a person, or STOP.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let conversation = model.conversation {
                        ForEach(conversation.messages) { message in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(message.role == "user" ? "You, as the lead" : conversation.ai_name)
                                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                Text(message.text).textSelection(.enabled)
                            }
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(message.role == "user" ? Color.secondary.opacity(0.08) : AuthenticationStyle.purple.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 16))
                            .id(message.id)
                        }
                        if let decision = conversation.decisions.last, decision.decision != "continue" {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Test outcome").font(.headline)
                                Text(decision.reason)
                                if !decision.handoff_summary.isEmpty { Text(decision.handoff_summary) }
                                if decision.strong_response == true {
                                    Text("Strong response").font(.headline)
                                    Text(decision.signal_reason ?? "")
                                    Text(decision.signal_evidence ?? "")
                                }
                                Text("This is simulated. No real handoff or booking occurred.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if model.isBusy { ProgressView("Your assistant is thinking…") }
                    if let error = model.error {
                        Text(error).foregroundStyle(.red)
                        if model.conversation == nil {
                            Button("Start a new practice attempt") { Task { await model.start() } }.disabled(model.isBusy)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }.padding(20)
            }
            .onChange(of: model.conversation?.messages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if model.conversation?.status == "active" {
                VStack(spacing: 12) {
                    TextField("Reply as the lead…", text: $model.replyText, axis: .vertical)
                        .lineLimit(1...4).textFieldStyle(.roundedBorder)
                        .disabled(model.isBusy || model.needsRetry)
                    Button(model.needsRetry ? "Retry reply" : "Send practice reply") { Task { await model.send() } }
                        .buttonStyle(AuthenticationButtonStyle())
                        .disabled(model.isBusy || (!model.needsRetry && (model.replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.replyText.count > 2000)))
                }.padding(16).background(.regularMaterial)
            }
        }
        .navigationTitle("Try your assistant")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Refresh conversation") { Task { await model.refresh() } }.disabled(model.conversation == nil)
                    Button("New test") { restarting = true }
                } label: { Image(systemName: "ellipsis.circle").accessibilityLabel("Practice options") }
                    .disabled(model.isBusy)
            }
        }
        .confirmationDialog("Start a new test with these settings?", isPresented: $restarting, titleVisibility: .visible) {
            Button("New test") { Task { await model.start() } }
        }
        .task { if model.conversation == nil { await model.start() } }
    }
}
