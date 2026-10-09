import Foundation
import Observation

@MainActor @Observable
final class SessionViewModel {
    var email = ""
    var password = ""
    private(set) var isBusy = false
    private(set) var isRestoring = true
    private(set) var errorMessage: String?
    private(set) var experience: PartnerExperienceViewModel?
    private(set) var identity: LiveIdentity?
    @ObservationIgnored private let auth: any SessionServicing
    @ObservationIgnored private let loadIdentity: @Sendable () async throws -> LiveIdentity
    @ObservationIgnored private let makeExperience: @MainActor (LiveIdentity) throws -> PartnerExperienceViewModel

    init(auth: any SessionServicing,
         loadIdentity: @escaping @Sendable () async throws -> LiveIdentity,
         makeExperience: @escaping @MainActor (LiveIdentity) throws -> PartnerExperienceViewModel) {
        self.auth = auth
        self.loadIdentity = loadIdentity
        self.makeExperience = makeExperience
    }
    func restore() async {
        guard isRestoring else { return }
        isBusy = true
        defer { isRestoring = false; isBusy = false }
        do { if try await auth.restore() { try await connect() } }
        catch { errorMessage = error.localizedDescription }
    }
    func signIn() async {
        guard !isBusy else { return }
        guard OnboardingValidation.email(email), !password.isEmpty else { errorMessage = "Enter your email and password."; return }
        isBusy = true; errorMessage = nil
        let credential = password; password = ""
        defer { isBusy = false }
        do {
            try await auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: credential)
            try await connect()
        } catch { errorMessage = error.localizedDescription }
    }
    func reconnect() async {
        guard !isBusy else { return }; isBusy = true; errorMessage = nil; defer { isBusy = false }
        do { try await connect() } catch { errorMessage = error.localizedDescription }
    }
    private func connect() async throws {
        let verified = try await loadIdentity()
        experience = try makeExperience(verified)
        identity = verified
    }
    func signOut() async {
        guard !isBusy else { return }; isBusy = true
        experience = nil; identity = nil; password = ""
        defer { isBusy = false }
        do { try await auth.signOut(); errorMessage = nil }
        catch { errorMessage = "Sign-out could not be fully confirmed. Please try again: \(error.localizedDescription)" }
    }
}
