import SwiftUI

struct PartnerReviewView: View {
    @State private var viewModel: PartnerReviewViewModel
    @State private var pendingAction: ReviewAction?
    let leadWorkspace: LeadWorkspaceViewModel?
    init(viewModel: PartnerReviewViewModel, leadWorkspace: LeadWorkspaceViewModel? = nil) { _viewModel = State(initialValue: viewModel); self.leadWorkspace = leadWorkspace }

    var body: some View {
        @Bindable var model = viewModel
        List {
            Section { DemoModeNotice() }
            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    Button("Refresh partner") { Task { await viewModel.load() } }.disabled(viewModel.isBusy)
                }
            }
            if let notice = viewModel.notice {
                Section { Label(notice, systemImage: "checkmark.circle").foregroundStyle(.indigo) }
            }
            if let partner = viewModel.partner {
                Section {
                    Text(partner.name).font(.title3.bold())
                    PartnerStatusBadge(status: partner.status)
                    Text("Updated \(partner.updatedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                }
                Section("Business & contact") {
                    row("Contact", partner.onboarding.contactName)
                    row("Email", partner.onboarding.email)
                    row("Proposed team", partner.onboarding.teamEmails)
                    row("Industry", partner.onboarding.industry)
                    row("Products/services", partner.onboarding.services)
                    row("Website", partner.onboarding.website)
                    row("Service area", partner.onboarding.serviceArea)
                    row("Time zone", partner.onboarding.timeZone)
                }
                Section("Recovery plan") {
                    row("Audiences", partner.onboarding.audience.map(\.rawValue).joined(separator: ", "))
                    row("Dormant period", "\(partner.onboarding.dormantDays) days")
                    row("Goal", partner.onboarding.goal.rawValue)
                    row("Offer", partner.onboarding.offer)
                    row("Exclusions", partner.onboarding.exclusions)
                }
                Section("Sales handoff") {
                    row("Qualification", partner.onboarding.qualification)
                    row("Sales team", partner.onboarding.salesContact)
                    row("Handoff email", partner.onboarding.handoffEmail)
                    row("Response expectation", "\(partner.onboarding.responseHours) hours")
                    row("Booking link", partner.onboarding.bookingURL)
                    row("AI boundaries", partner.onboarding.aiBoundaries)
                }
                Section("Lead data & eligibility") {
                    if let leadWorkspace {
                        NavigationLink("Open lead workspace") { LeadWorkspaceView(viewModel: leadWorkspace) }
                    }
                    row("Source", partner.onboarding.leadSource)
                    row("Eligibility notes", partner.onboarding.eligibilityNotes)
                    if let summary = partner.onboarding.importSummary {
                        row("File", summary.fileName)
                        row("Rows inspected", "\(summary.totalRows)")
                        row("Unique plausible numbers", "\(summary.validContacts)")
                        row("Duplicate numbers", "\(summary.duplicateContacts)")
                        row("Invalid numbers", "\(summary.invalidContacts)")
                    } else { Text("No lead database provided.").foregroundStyle(.secondary) }
                }
                Section("Reporting & proposed agreement") {
                    row("Evidence source", partner.onboarding.evidenceSource.rawValue)
                    row("Reporting systems", partner.onboarding.reportingSystem)
                    row("Compensation", partner.onboarding.compensation.title)
                    row("Proposed terms", partner.onboarding.commercialTerms)
                    row("Reporting deadline", "\(partner.onboarding.reportingDays) days")
                    row("Owner visibility acknowledged", partner.onboarding.acceptsVisibility ? "Yes" : "No")
                    Text("These are sample terms and readiness flags. No real agreement or evidence has been verified.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Pilot readiness") {
                    readiness("Contact eligibility", complete: partner.readiness.eligibilityReviewed)
                    readiness("Messaging setup", complete: partner.readiness.messagingReady)
                    readiness("Reporting sources", complete: partner.readiness.reportingReady)
                    readiness("Final agreement", complete: partner.readiness.agreementFinalized)
                    if partner.missingLaunchRequirements.isEmpty {
                        Label("All demo requirements complete", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        ForEach(partner.missingLaunchRequirements, id: \.self) { Text($0).font(.subheadline).foregroundStyle(.secondary) }
                    }
                }
                Section("Owner decision") {
                    TextField("Decision note", text: $model.decisionNote, axis: .vertical).lineLimit(3...8)
                    Text("Add at least five characters to request changes or pause. Your note is recorded in the local decision history.").font(.caption).foregroundStyle(.secondary)
                    if partner.status == .submitted {
                        Button("Approve sample pilot") { pendingAction = .approve }.disabled(!partner.canApprove || viewModel.isBusy)
                        Button("Request changes") { pendingAction = .requestChanges }.disabled(viewModel.isBusy)
                    }
                    if partner.status == .paused {
                        Button("Resume previous status") { pendingAction = .resume }.disabled(viewModel.isBusy)
                    } else {
                        Button("Pause partner", role: .destructive) { pendingAction = .pause }.disabled(viewModel.isBusy)
                    }
                    if partner.status == .changesRequested {
                        Text("Awaiting a revised partner submission. This demo does not submit revisions on the partner’s behalf.").font(.caption).foregroundStyle(.secondary)
                    }
                    if viewModel.isBusy { ProgressView("Updating demo…") }
                }
                Section("Decision history") {
                    if partner.history.isEmpty {
                        Text("No decisions recorded yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(partner.history.reversed()) { event in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(event.action.rawValue).font(.headline)
                                Text("\(event.previousStatus.rawValue) → \(event.resultingStatus.rawValue)").font(.subheadline)
                                if !event.reason.isEmpty { Text(event.reason).font(.subheadline) }
                                Text("\(event.actorName) · \(event.timestamp.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        }
                    }
                }
            } else if viewModel.isBusy { ProgressView("Loading partner…") }
        }
        .navigationTitle("Partner review")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .confirmationDialog("Update this sample partner?", isPresented: Binding(get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }), presenting: pendingAction) { action in
            Button(action.rawValue, role: action == .pause ? .destructive : nil) {
                Task { await viewModel.decide(action) }
            }
            Button("Cancel", role: .cancel) { pendingAction = nil }
        } message: { _ in
            Text("This changes local demo data only. It does not notify a partner or activate messaging.")
        }
        .tint(.indigo)
    }
    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value.isEmpty ? "Not provided" : value).font(.subheadline).textSelection(.enabled)
        }.padding(.vertical, 2)
    }
    private func readiness(_ title: String, complete: Bool) -> some View {
        Label(title + (complete ? " — demo complete" : " — pending"), systemImage: complete ? "checkmark.circle.fill" : "circle")
            .font(.subheadline).foregroundStyle(complete ? .green : .secondary)
    }
}
