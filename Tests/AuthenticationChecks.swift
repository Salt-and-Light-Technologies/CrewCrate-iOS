import Foundation

@main
struct AuthenticationChecks {
    static func main() throws {
        let id = UUID()
        let data = Data("{\"user_id\":\"\(id)\",\"is_owner\":false}".utf8)
        let identity = try JSONDecoder().decode(AuthenticatedIdentity.self, from: data)
        precondition(identity.userID == id && !identity.isOwner)
        print("Authentication model checks passed.")
    }
}
