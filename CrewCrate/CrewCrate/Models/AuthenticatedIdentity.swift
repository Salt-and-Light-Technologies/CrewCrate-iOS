import Foundation

nonisolated struct AuthenticatedIdentity: Decodable, Sendable {
    let userID: UUID
    let isOwner: Bool
    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case isOwner = "is_owner"
    }
}
