import Foundation

nonisolated struct LiveConfiguration: Sendable {
    static let apiURL = URL(string: "https://crewcrate-api.onrender.com")!
    static let authURL = URL(string: "https://volklcrfpyfddrekulna.supabase.co/auth/v1")!
    // Public client key; all data authorization is enforced by the backend.
    static let publishableKey = "sb_publishable_Q0yIfawQnnqLm-_SSDM0tg_nxqYGo3X"
}
