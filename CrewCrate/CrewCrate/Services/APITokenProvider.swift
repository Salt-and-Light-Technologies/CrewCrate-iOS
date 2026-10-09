import Foundation

nonisolated protocol APITokenProvider: Sendable {
    func accessToken() async throws -> String
}
