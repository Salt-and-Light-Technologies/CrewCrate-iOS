import SwiftUI
import UserNotifications

struct WorkerInboxView: View {
    let businesses: [BusinessSummary]
    @State private var businessID: UUID
    @State private var model: WorkerInboxModel
    @State private var showingDetail = false
    @State private var detailBusinessID: UUID
    @State private var showingAlerts = false
    @State private var notificationNotice: String?
    @Environment(\.scenePhase) private var phase
    @Environment(WorkerPushState.self) private var push

    init(businesses: [BusinessSummary], service: any WorkerServicing) {
        self.businesses = businesses
        let first = businesses[0].id
        _businessID = State(initialValue: first)
        _detailBusinessID = State(initialValue: first)
        _model = State(initialValue: WorkerInboxModel(service: service))
    }
    var body: some View {
        List {
            if businesses.count > 1 {
                Picker("Business", selection: $businessID) {
                    ForEach(businesses) { Text($0.name).tag($0.id) }
                }
            }
            Section {
                Text("Leads ready for follow-up").font(.headline)
                Text("These are recorded follow-up conversations. SMS delivery and incoming SMS are not connected yet.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button { showingAlerts = true } label: {
                    Label("Alerts · \(model.unread) unread", systemImage: "bell")
                }
                Button("Enable device notifications") {
                    Task {
                        do { notificationNotice = try await push.enable(service: model.service) }
                        catch { notificationNotice = error.localizedDescription }
                    }
                }
                if let notificationNotice { Text(notificationNotice).font(.footnote).foregroundStyle(.secondary) }
                if let error = push.registrationError { Text(error).font(.footnote).foregroundStyle(.red) }
            }
            Section("Incoming leads") {
                if model.busy && model.leads.isEmpty { ProgressView("Loading leads…") }
                if !model.busy && model.leads.isEmpty && model.error == nil {
                    ContentUnavailableView("No incoming leads yet", systemImage: "tray",
                        description: Text("Interested leads will appear here when follow-up is recorded."))
                }
                ForEach(model.leads) { lead in
                    Button { open(businessID, lead.id) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(lead.name.isEmpty ? lead.phone : lead.name).font(.headline)
                            Text(lead.status.capitalized).font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 6)
                    }
                }
            }
            if let error = model.error {
                Section { Text(error).foregroundStyle(.red); Button("Refresh") { Task { await model.load(businessID) } } }
            }
        }
        .navigationTitle("Incoming leads")
        .refreshable { await model.load(businessID) }
        .navigationDestination(isPresented: $showingDetail) {
            WorkerConversationView(businessID: detailBusinessID, model: model)
        }
        .sheet(isPresented: $showingAlerts) {
            NavigationStack {
                List(model.alerts) { alert in
                    Button {
                        showingAlerts = false
                        open(alert.partner_id, alert.conversation_id)
                    } label: {
                        Label(alert.title, systemImage: alert.read ? "bubble.left" : "circle.fill")
                    }
                }.navigationTitle("Lead alerts")
                    .toolbar { Button("Done") { showingAlerts = false } }
            }
        }
        .task(id: "\(businessID)-\(phase)") {
            guard phase == .active else { return }
            repeat {
                await model.load(businessID)
                await push.restoreRegistration(service: model.service)
                await handlePush()
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
            } while !Task.isCancelled
        }
        .onChange(of: businesses.map(\.id)) { _, ids in
            if !ids.contains(businessID), let first = ids.first { businessID = first }
        }
        .onChange(of: model.unread) { _, _ in
            Task { await push.refreshAlerts(service: model.service) }
        }
        .onChange(of: push.openNotificationID) { _, _ in Task { await handlePush() } }
        .onChange(of: push.refreshID) { _, _ in Task { await model.load(businessID) } }
        .onChange(of: push.deviceToken) { _, _ in Task { await push.syncRegistration(service: model.service) } }
    }
    private func open(_ business: UUID, _ conversation: UUID) {
        guard businesses.contains(where: { $0.id == business }) else { return }
        Task {
            if await model.open(business, conversation: conversation) {
                detailBusinessID = business
                showingDetail = true
            }
        }
    }
    private func handlePush() async {
        guard let id = push.openNotificationID else { return }
        // Resolve notification through authenticated, business-scoped server data.
        guard let alert = model.alerts.first(where: { $0.id == id }) else { return }
        push.openNotificationID = nil
        open(alert.partner_id, alert.conversation_id)
    }
}

private struct WorkerConversationView: View {
    let businessID: UUID
    @Bindable var model: WorkerInboxModel
    @State private var note = ""
    @State private var status = "handoff"
    var body: some View {
        Form {
            if let lead = model.detail {
                Section("Lead") {
                    Text(lead.name.isEmpty ? "Lead" : lead.name).font(.headline)
                    LabeledContent("Phone", value: lead.phone).textSelection(.enabled)
                    LabeledContent("Email", value: lead.email.isEmpty ? "Not recorded" : lead.email).textSelection(.enabled)
                    Text("Manual follow-up record · these notes are internal and are not sent as SMS.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Conversation notes") {
                    ForEach(lead.events ?? [], id: \.revision) { event in
                        VStack(alignment: .leading) {
                            Text(event.status.capitalized).font(.caption).foregroundStyle(.secondary)
                            Text(event.note)
                        }
                    }
                }
                Section("Record follow-up") {
                    Picker("Status", selection: $status) {
                        Text("Interested").tag("interested")
                        Text("Needs follow-up").tag("handoff")
                        Text("Appointment recorded").tag("appointment")
                        Text("Closed").tag("closed")
                    }
                    TextField("Internal note", text: $note, axis: .vertical).lineLimit(3...8)
                    Button("Save note") {
                        Task { await model.save(businessID, note: note, status: status); if model.error == nil { note = "" } }
                    }.disabled(model.busy || note.trimmingCharacters(in: .whitespacesAndNewlines).count < 5)
                }
            }
            if let error = model.error { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Follow-up").onAppear { status = model.detail?.status ?? "handoff" }
    }
}
