import SwiftUI

struct CampaignEditorView: View {
    @State private var viewModel: CampaignEditorViewModel
    @State private var pendingControl: String?
    @State private var requirementExplanation: String?
    init(viewModel: CampaignEditorViewModel) { _viewModel = State(initialValue: viewModel) }
    private var locked: Bool { viewModel.record?.status == .paused || viewModel.record?.status == .archived }
    var body: some View {
        @Bindable var model = viewModel
        ScrollViewReader { scroll in
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
            }.disabled(locked).id("details")
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
            }.disabled(locked).id("limits")
            Section("Recipients — \(viewModel.config.leadIDs.count) selected") {
                Picker("Lead list", selection: $model.selectedImportID) {
                    Text("All uploaded lists").tag(nil as UUID?)
                    ForEach(viewModel.importedFiles) { file in Text("\(file.fileName) (\(file.imported))").tag(Optional(file.id)) }
                }.disabled(viewModel.isLoading).onChange(of: viewModel.selectedImportID) { _, _ in Task { await viewModel.reloadRecipients() } }
                if viewModel.moreFiles { Button("Load more lead lists") { Task { await viewModel.loadMoreFiles() } } }
                Text("Review your uploaded contacts, record permission and choose recipients in the lead list below.").font(.caption).foregroundStyle(.secondary)
                NavigationLink("Manage imported contacts and permission") { LeadWorkspaceView(viewModel: viewModel.contactWorkspace(), campaign: viewModel) }
                Text("\(viewModel.config.leadIDs.count) selected · up to 500 per campaign").font(.caption).foregroundStyle(.secondary)
            }.disabled(locked).id("recipients")
            Section("Preparation") {
                if let record = viewModel.record {
                    LabeledContent("Status", value: record.status.title)
                    if record.ownerHold { Label("Owner hold — owner must release", systemImage: "lock.fill").foregroundStyle(.orange) }
                    LabeledContent("Permitted recipients", value: "\(record.recipientCount)")
                    ForEach(Array(record.blockers.enumerated()), id: \.offset) { item in
                        Button {
                            if item.element.localizedCaseInsensitiveContains("recipient") || item.element.localizedCaseInsensitiveContains("eligibility") {
                                withAnimation { scroll.scrollTo("recipients", anchor: .top) }
                            } else {
                                requirementExplanation = explanation(for: item.element)
                            }
                        } label: { Label(item.element + " — review", systemImage: "info.circle").foregroundStyle(.orange) }
                    }
                }
                Button("Review campaign details and sales handoff") { withAnimation { scroll.scrollTo("details", anchor: .top) } }
                Text("Check the offer, AI instructions, qualification rules and sales handoff email.").font(.caption).foregroundStyle(.secondary)
                Toggle("I confirm the campaign details", isOn: $model.detailsConfirmed)
                Button("Review contact limits and sending hours") { withAnimation { scroll.scrollTo("limits", anchor: .top) } }
                Toggle("I confirm the planned limits", isOn: $model.limitsConfirmed)
                Button("Review recipient eligibility and permission") { withAnimation { scroll.scrollTo("recipients", anchor: .top) } }
                Text("Eligible means your team reviewed the contact for this offer. SMS permission must be recorded separately, and opted-out contacts cannot be selected.").font(.caption).foregroundStyle(.secondary)
                Toggle("I confirm the selected recipients", isOn: $model.recipientsConfirmed)
                Text("Editing the plan clears these confirmations. CrewCrate checks workspace requirements again when you finalize.").font(.caption).foregroundStyle(.secondary)
                Text(viewModel.hasUnsavedChanges ? "Unsaved changes" : "No unsaved edits").font(.caption).foregroundStyle(.secondary)
                Button("Save draft") { Task { await viewModel.save() } }.disabled(locked || viewModel.isLoading)
                Button("Finalize campaign") { Task { await viewModel.finalize() } }.disabled(locked || viewModel.isLoading || !viewModel.reviewsComplete)
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
        .alert("Workspace requirement", isPresented: Binding(get: { requirementExplanation != nil }, set: { if !$0 { requirementExplanation = nil } })) {
            Button("OK") { requirementExplanation = nil }
        } message: { Text(requirementExplanation ?? "") }
        }
    }
    private func explanation(for requirement: String) -> String {
        if requirement.localizedCaseInsensitiveContains("messaging") { return "CrewCrate must verify the messaging setup before this workspace is ready for outreach. An SMS provider is not connected yet. This cannot be approved by checking a campaign box." }
        if requirement.localizedCaseInsensitiveContains("reporting") { return "CrewCrate must verify the reporting source chosen during partner setup so campaign outcomes can be checked. Contact your CrewCrate administrator to complete this workspace requirement." }
        if requirement.localizedCaseInsensitiveContains("agreement") { return "Your partnership agreement must be finalized with CrewCrate. The proposed terms entered during setup do not complete that agreement. Contact your CrewCrate administrator." }
        if requirement.localizedCaseInsensitiveContains("approved") || requirement.localizedCaseInsensitiveContains("hold") { return "CrewCrate must approve your partner workspace or release its hold. Campaign confirmations do not change workspace approval. Contact your CrewCrate administrator." }
        return requirement + ". Review your campaign details, limits and recipient selection, save your changes, then finalize again."
    }
}
