import Foundation

nonisolated struct WorkerInvitation: Decodable, Identifiable, Sendable {
    let id: UUID
    let email: String
    let expires_at: String
    let status: String
    var token: String? = nil
}
nonisolated struct TeamMember: Decodable, Identifiable, Sendable {
    let user_id: UUID
    let display_name: String
    let role: String
    let active: Bool
    var id: UUID { user_id }
}
nonisolated struct WorkerTeam: Decodable, Sendable {
    let members: [TeamMember]
    let invitations: [WorkerInvitation]
}
nonisolated struct IncomingLead: Decodable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let phone: String
    let email: String
    let status: String
    let revision: Int
    let source: String
    var events: [FollowUpEvent]? = nil
}
nonisolated struct FollowUpEvent: Decodable, Sendable {
    let revision: Int
    let note: String
    let status: String
}
nonisolated struct WorkerAlert: Decodable, Identifiable, Sendable, Hashable {
    let id: UUID
    let partner_id: UUID
    let conversation_id: UUID
    let read: Bool
    let title: String
}
