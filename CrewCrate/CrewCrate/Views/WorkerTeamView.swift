import SwiftUI

struct WorkerTeamView: View {
    let business: BusinessSummary
    @State private var model: WorkerTeamModel
    init(business: BusinessSummary, service: any WorkerServicing) {
        self.business = business
        _model = State(initialValue: WorkerTeamModel(service: service))
    }
    var body: some View {
        @Bindable var model = model
        Form {
            Section("Invite a worker") {
                TextField("Worker’s email", text: $model.email).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Create invitation") { Task { await model.invite(business.id) } }
                    .disabled(model.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("Share the code with this worker. They create their own login and verify this email before joining. Codes expire after seven days.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let invitation = model.invitation, let token = invitation.token {
                Section("Share invitation") {
                    Text("For \(invitation.email)")
                    Text(token).font(.caption.monospaced()).textSelection(.enabled)
                    ShareLink(item: "Join \(business.name) in CrewCrate. Create a worker account with \(invitation.email), verify your email and log in. Choose Accept worker invitation and enter this code: \(token). Expires in seven days.") {
                        Label("Share invitation code", systemImage: "square.and.arrow.up")
                    }
                }
            }
            if let team = model.team {
                Section("Workers") {
                    let workers = team.members.filter { $0.role == "worker" && $0.active }
                    if workers.isEmpty { Text("No workers have joined yet.").foregroundStyle(.secondary) }
                    ForEach(workers) { worker in
                        HStack {
                            Text(worker.display_name.isEmpty ? "Worker" : worker.display_name)
                            Spacer()
                            Button("Remove", role: .destructive) { Task { await model.remove(business.id, worker: worker.id) } }
                        }
                    }
                }
                Section("Invitations") {
                    ForEach(team.invitations) { invitation in
                        VStack(alignment: .leading) {
                            Text(invitation.email)
                            Text(invitation.status.capitalized).font(.caption).foregroundStyle(.secondary)
                            if invitation.status == "pending" {
                                Button("Revoke", role: .destructive) { Task { await model.revoke(business.id, invitation: invitation.id) } }
                            }
                        }
                    }
                }
            }
            if let error = model.error { Text(error).foregroundStyle(.red) }
            if model.busy { ProgressView("Updating team…") }
        }
        .disabled(model.busy).navigationTitle("Team")
        .task { await model.load(business.id) }
    }
}

struct AcceptWorkerInvitationView: View {
    @State private var model: WorkerTeamModel
    @Environment(\.dismiss) private var dismiss
    let accepted: @MainActor () async -> Void
    init(service: any WorkerServicing, accepted: @escaping @MainActor () async -> Void) {
        _model = State(initialValue: WorkerTeamModel(service: service))
        self.accepted = accepted
    }
    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Text("Join your business team").font(.title2.bold())
                Text("Use the invitation code your business shared. You must be signed in with the invited, verified email.")
            }
            Section {
                TextField("Your full name", text: $model.name).textContentType(.name)
                TextField("Invitation code", text: $model.token).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Accept invitation") {
                    Task { if await model.accept() { await accepted(); dismiss() } }
                }.disabled(model.token.isEmpty || model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let error = model.error { Text(error).foregroundStyle(.red) }
            if model.busy { ProgressView("Joining your team…") }
        }.disabled(model.busy).navigationTitle("Accept invitation")
    }
}
