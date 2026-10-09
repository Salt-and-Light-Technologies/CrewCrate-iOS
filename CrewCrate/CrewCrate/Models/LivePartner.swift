import Foundation

nonisolated struct LivePartner: Decodable, Identifiable, Sendable {
    let id: UUID; let name: String; let status: String; let revision: Int
}
