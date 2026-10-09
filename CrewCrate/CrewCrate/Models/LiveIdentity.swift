import Foundation

nonisolated struct LiveIdentity: Decodable, Sendable {
    let user_id: UUID
    let is_owner: Bool
}
