import Foundation
import Observation

@MainActor @Observable final class WorkerTeamModel {
    var team: WorkerTeam?
    var email = ""
    var invitation: WorkerInvitation?
    var token = ""
    var name = ""
    var error: String?
    var busy = false
    let service: any WorkerServicing
    init(service: any WorkerServicing) { self.service = service }
    func load(_ business: UUID) async {
        await run { self.team = try await self.service.team(business) }
    }
    func invite(_ business: UUID) async {
        await run {
            self.invitation = try await self.service.inviteWorker(business, email: self.email)
            self.team = try await self.service.team(business)
        }
    }
    func revoke(_ business: UUID, invitation: UUID) async {
        await run {
            try await self.service.revokeInvitation(business, invitation: invitation)
            self.team = try await self.service.team(business)
        }
    }
    func remove(_ business: UUID, worker: UUID) async {
        await run {
            try await self.service.removeWorker(business, worker: worker)
            self.team = try await self.service.team(business)
        }
    }
    func accept() async -> Bool {
        var accepted = false
        await run {
            try await self.service.acceptWorkerInvitation(token: self.token.trimmingCharacters(in: .whitespacesAndNewlines), name: self.name)
            accepted = true
        }
        return accepted
    }
    private func run(_ action: () async throws -> Void) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do { try await action() }
        catch { self.error = error.localizedDescription }
    }
}

@MainActor @Observable final class WorkerInboxModel {
    var leads: [IncomingLead] = []
    var alerts: [WorkerAlert] = []
    var detail: IncomingLead?
    var error: String?
    var banner: WorkerAlert?
    var busy = false
    private var seen = Set<UUID>()
    private var loadedAlerts = false
    let service: any WorkerServicing
    init(service: any WorkerServicing) { self.service = service }
    var unread: Int { alerts.filter { !$0.read }.count }
    func load(_ business: UUID) async {
        guard !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            async let incoming = service.incomingLeads(business)
            async let notices = service.workerAlerts()
            let (newLeads, newAlerts) = try await (incoming, notices)
            leads = newLeads
            if loadedAlerts { banner = newAlerts.first { !$0.read && !seen.contains($0.id) } ?? banner }
            seen.formUnion(newAlerts.map(\.id)); loadedAlerts = true
            alerts = newAlerts
        } catch is CancellationError { }
        catch {
            leads = []; alerts = []; banner = nil
            self.error = error.localizedDescription
        }
    }
    func open(_ business: UUID, conversation: UUID) async -> Bool {
        do {
            detail = try await service.incomingLead(business, conversation: conversation)
            for alert in alerts where alert.partner_id == business && alert.conversation_id == conversation && !alert.read {
                try await service.readWorkerAlert(alert.id)
            }
            alerts = try await service.workerAlerts()
            banner = nil
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func save(_ business: UUID, note: String, status: String) async {
        guard let detail, !busy else { return }
        busy = true; error = nil
        defer { busy = false }
        do {
            try await service.saveFollowUp(business, lead: detail, note: note, status: status)
            self.detail = try await service.incomingLead(business, conversation: detail.id)
        } catch { self.error = error.localizedDescription }
    }
}
