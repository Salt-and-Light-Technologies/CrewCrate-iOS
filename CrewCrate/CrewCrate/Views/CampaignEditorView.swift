import SwiftUI

struct CampaignEditorView: View {
    @State private var viewModel: CampaignEditorViewModel
    @State private var pendingControl: String?
    init(viewModel: CampaignEditorViewModel) { _viewModel = State(initialValue: viewModel) }
    private var locked: Bool { viewModel.record?.status == .paused || viewModel.record?.status == .archived }
    var body: some View {
        @Bindable var model = viewModel
        List {
            Section { MessagingBoundaryNotice(isDemo: viewModel.isDemo) }
            if viewModel.isLoading { Section { ProgressView("Loading saved lists and campaign settings…") } }
            if let error = viewModel.errorMessage { Section { Text(error).foregroundStyle(.red) } }
            if let notice = viewModel.notice { Section { Text(notice).foregroundStyle(.indigo) } }
            Section("Campaign details") {
                TextField("Campaign title", text: $model.config.name)
                TextField("Promotion or offer", text: $model.config.offer, axis: .vertical).lineLimit(3...6)
                Picker("AI name", selection: $model.aiName) {
                    Text("Choose a name").tag("")
                    Section("Female names") { ForEach(CampaignAIName.femaleNames, id: \.self) { Text($0).tag($0) } }
                    Section("Male names") { ForEach(CampaignAIName.maleNames, id: \.self) { Text($0).tag($0) } }
                }
                TextField("Describe what you want the AI to accomplish", text: $model.aiBrief, axis: .vertical).lineLimit(4...10)
                Text("Describe your audience, goals, tone, promotion details and when to hand leads to your team.").font(.caption).foregroundStyle(.secondary)
                TextField("Qualification and handoff rules", text: $model.config.qualification, axis: .vertical).lineLimit(3...6)
                Picker("Sales handoff email", selection: $model.config.handoffEmail) {
                    Text("Choose an email").tag("")
                    if !viewModel.config.handoffEmail.isEmpty && !viewModel.handoffEmails.contains(viewModel.config.handoffEmail) {
                        Text(viewModel.config.handoffEmail + " (previously saved)").tag(viewModel.config.handoffEmail)
                    }
                    ForEach(viewModel.handoffEmails, id: \.self) { Text($0).tag($0) }
                }
                if viewModel.handoffEmails.isEmpty { Text("Add your sales handoff emails in Account before preparing a campaign.").font(.caption).foregroundStyle(.secondary) }
                if viewModel.isDemo { Button("Use sample recovery plan") { viewModel.useSamplePlan() } }
            }.disabled(locked)
            Section("Planned limits") {
                TextField("IANA time zone", text: $model.config.timeZone).textInputAutocapitalization(.never).autocorrectionDisabled()
                DatePicker("Start time", selection: $model.startTime, in: viewModel.sendingTimeRange, displayedComponents: .hourAndMinute).datePickerStyle(.compact).environment(\.timeZone, viewModel.sendingTimeZone)
                DatePicker("End time", selection: $model.endTime, in: viewModel.sendingTimeRange, displayedComponents: .hourAndMinute).datePickerStyle(.compact).environment(\.timeZone, viewModel.sendingTimeZone)
                Stepper(value: $model.config.dailyLimit, in: 1...Int.max) {
                    HStack {
                        Text("Daily contact limit")
                        Spacer()
                        TextField("25", value: $model.config.dailyLimit, format: .number.grouping(.never))
                            .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(maxWidth: 80)
                            .accessibilityLabel("Daily contact limit")
                    }
                }
                Stepper("Maximum follow-ups: \(viewModel.config.followUpLimit)", value: $model.config.followUpLimit, in: 0...3)
                Text("Limits and hours are stored for future sending. No scheduler or follow-ups run yet.").font(.caption).foregroundStyle(.secondary)
            }.disabled(locked)
            Section("Recipients — \(viewModel.config.leadIDs.count) selected") {
                Picker("Lead list", selection: $model.selectedImportID) {
                    Text("All uploaded lists").tag(nil as UUID?)
                    ForEach(viewModel.importedFiles) { file in Text("\(file.fileName) (\(file.imported))").tag(Optional(file.id)) }
                }.disabled(viewModel.isLoading).onChange(of: viewModel.selectedImportID) { _, _ in Task { await viewModel.reloadRecipients() } }
                if viewModel.moreFiles { Button("Load more lead lists") { Task { await viewModel.loadMoreFiles() } } }
                Text("Imported contacts are shown below. Only eligible contacts with recorded SMS permission and no opt-out can be selected.").font(.caption).foregroundStyle(.secondary)
                NavigationLink("Manage imported contacts and permission") { LeadWorkspaceView(viewModel: viewModel.contactWorkspace()) }
                if viewModel.candidates.isEmpty { Text("No eligible leads available.").foregroundStyle(.secondary) }
                ForEach(viewModel.candidates) { lead in
                    Button { viewModel.toggle(lead) } label: {
                        HStack {
                            Image(systemName: viewModel.config.leadIDs.contains(lead.id) ? "checkmark.circle.fill" : "circle")
                            VStack(alignment: .leading) {
                                Text(lead.name.isEmpty ? lead.phone : lead.name)
                                Text(lead.optedOut ? "Opted out" : "\(lead.status.title) · SMS permission: \(lead.smsPermission)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }.disabled(!viewModel.config.leadIDs.contains(lead.id) && (lead.status != .eligible || lead.smsPermission != "recorded" || lead.optedOut))
                }
                if viewModel.candidatesTruncated { Button("Load more contacts") { Task { await viewModel.loadMoreCandidates() } } }
                Text("Each campaign can select up to 500 recipients.").font(.caption).foregroundStyle(.secondary)
            }.disabled(locked)
            Section("Preparation") {
                if let record = viewModel.record {
                    LabeledContent("Status", value: record.status.title)
                    if record.ownerHold { Label("Owner hold — owner must release", systemImage: "lock.fill").foregroundStyle(.orange) }
                    LabeledContent("Permitted recipients", value: "\(record.recipientCount)")
                    ForEach(Array(record.blockers.enumerated()), id: \.offset) { Text($0.element).font(.subheadline).foregroundStyle(.orange) }
                }
                Text(viewModel.hasUnsavedChanges ? "Unsaved changes" : "No unsaved edits").font(.caption).foregroundStyle(.secondary)
                Button("Save draft") { Task { await viewModel.save() } }.disabled(locked || viewModel.isLoading)
                Button("Check and prepare campaign") { Task { await viewModel.prepare() } }.disabled(locked || viewModel.isLoading)
                Text("Preparation rechecks the current recipients. Ready to connect does not mean launched or delivered.").font(.caption).foregroundStyle(.secondary)
                if viewModel.hasUnsavedChanges { Button("Discard edits and refresh", role: .destructive) { Task { await viewModel.load(discardEdits: true) } } }
            }
            if let record = viewModel.record {
                Section("Campaign controls") {
                    TextField("Reason for status change", text: $model.controlReason, axis: .vertical).lineLimit(2...5)
                    if record.status == .paused { Button("Resume as draft") { pendingControl = "resume" } }
                    else if record.status != .archived { Button("Pause plan", role: .destructive) { pendingControl = "pause" } }
                    if record.status != .archived { Button("Archive plan", role: .destructive) { pendingControl = "archive" } }
                }
                if let conversations = viewModel.conversations() {
                    Section("Conversation workspace") {
                        NavigationLink("Open manual follow-up tracking") { ConversationListView(viewModel: conversations) }
                        Text("Record internal follow-up status and notes. No incoming SMS, delivered messages, sales evidence or revenue is inferred.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("Plan history") {
                    ForEach(viewModel.history) { event in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.action.replacingOccurrences(of: "_", with: " ").capitalized).font(.headline)
                            Text(event.detail).font(.subheadline)
                            Text("\(event.actorName) · \(event.timestamp.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if viewModel.moreHistory { Button("Load more history") { Task { await viewModel.loadMoreHistory() } } }
                }
            }
            if viewModel.isBusy { ProgressView("Updating plan…") }
        }.disabled(viewModel.blocksEditing)
            .navigationTitle("Campaign details").navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }.refreshable { await viewModel.load() }
            .confirmationDialog("Change campaign status?", isPresented: Binding(get: { pendingControl != nil }, set: { if !$0 { pendingControl = nil } }), presenting: pendingControl) { action in
                Button(action.capitalized, role: action == "resume" ? nil : .destructive) { Task { await viewModel.control(action) } }
                Button("Cancel", role: .cancel) {}
            } message: { _ in Text("The reason is saved in plan history. Sending remains disabled. Archived plans cannot be edited.") }
    }
}
