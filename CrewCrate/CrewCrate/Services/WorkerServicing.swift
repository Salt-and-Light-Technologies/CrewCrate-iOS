import Foundation

nonisolated protocol WorkerServicing: Sendable {
    func team(_ business: UUID) async throws -> WorkerTeam
    func inviteWorker(_ business: UUID, email: String) async throws -> WorkerInvitation
    func revokeInvitation(_ business: UUID, invitation: UUID) async throws
    func removeWorker(_ business: UUID, worker: UUID) async throws
    func acceptWorkerInvitation(token: String, name: String) async throws
    func incomingLeads(_ business: UUID) async throws -> [IncomingLead]
    func incomingLead(_ business: UUID, conversation: UUID) async throws -> IncomingLead
    func saveFollowUp(_ business: UUID, lead: IncomingLead, note: String, status: String) async throws
    func workerAlerts() async throws -> [WorkerAlert]
    func readWorkerAlert(_ id: UUID) async throws
    func registerWorkerDevice(token: String, environment: String) async throws
    func unregisterWorkerDevice(token: String) async throws
}

extension SupabaseSession: WorkerServicing {
    private struct OK: Decodable, Sendable { let ok: Bool }
    func team(_ business: UUID) async throws -> WorkerTeam {
        try await apiRequest("v1/partners/\(business)/team")
    }
    func inviteWorker(_ business: UUID, email: String) async throws -> WorkerInvitation {
        struct Body: Encodable { let email: String }
        return try await apiRequest("v1/partners/\(business)/worker-invitations", method: "POST",
            body: JSONEncoder().encode(Body(email: email)))
    }
    func revokeInvitation(_ business: UUID, invitation: UUID) async throws {
        let _: OK = try await apiRequest("v1/partners/\(business)/worker-invitations/\(invitation)", method: "DELETE")
    }
    func removeWorker(_ business: UUID, worker: UUID) async throws {
        let _: OK = try await apiRequest("v1/partners/\(business)/workers/\(worker)", method: "DELETE")
    }
    func acceptWorkerInvitation(token: String, name: String) async throws {
        struct Body: Encodable { let token: String; let display_name: String }
        struct Accepted: Decodable, Sendable { let partner_id: UUID }
        let _: Accepted = try await apiRequest("v1/me/worker-invitations/accept", method: "POST",
            body: JSONEncoder().encode(Body(token: token, display_name: name)))
    }
    func incomingLeads(_ business: UUID) async throws -> [IncomingLead] {
        var result: [IncomingLead] = []
        while true {
            let page: [IncomingLead] = try await apiRequest("v1/partners/\(business)/incoming-leads", query: [
                URLQueryItem(name: "limit", value: "100"), URLQueryItem(name: "offset", value: String(result.count))])
            result += page
            if page.count < 100 { return result }
            try Task.checkCancellation()
        }
    }
    func incomingLead(_ business: UUID, conversation: UUID) async throws -> IncomingLead {
        try await apiRequest("v1/partners/\(business)/incoming-leads/\(conversation)")
    }
    func saveFollowUp(_ business: UUID, lead: IncomingLead, note: String, status: String) async throws {
        struct Body: Encodable { let expected_revision: Int; let note: String; let status: String }
        let _: OK = try await apiRequest("v1/partners/\(business)/incoming-leads/\(lead.id)/notes", method: "POST",
            body: JSONEncoder().encode(Body(expected_revision: lead.revision, note: note, status: status)))
    }
    func workerAlerts() async throws -> [WorkerAlert] {
        var result: [WorkerAlert] = []
        while true {
            let page: [WorkerAlert] = try await apiRequest("v1/me/worker-notifications", query: [
                URLQueryItem(name: "limit", value: "100"), URLQueryItem(name: "offset", value: String(result.count))])
            result += page
            if page.count < 100 { return result }
            try Task.checkCancellation()
        }
    }
    func readWorkerAlert(_ id: UUID) async throws {
        let _: OK = try await apiRequest("v1/me/worker-notifications/\(id)/read", method: "POST")
    }
    func registerWorkerDevice(token: String, environment: String) async throws {
        struct Body: Encodable { let token: String; let environment: String }
        let _: OK = try await apiRequest("v1/me/worker-devices", method: "POST",
            body: JSONEncoder().encode(Body(token: token, environment: environment)))
    }
    func unregisterWorkerDevice(token: String) async throws {
        let _: OK = try await apiRequest("v1/me/worker-devices/\(token)", method: "DELETE")
    }
}
