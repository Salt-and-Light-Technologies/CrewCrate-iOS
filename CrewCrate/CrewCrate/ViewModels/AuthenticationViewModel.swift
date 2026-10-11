import Foundation
import Observation

@MainActor
@Observable
final class AuthenticationViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var notice: String?
    var isBusy = false
    var isRestoring = true
    var needsPasswordUpdate = false
    var identity: AuthenticatedIdentity?
    private var pendingCallback: URL?
    private let service: any AuthenticationServicing

    init(service: any AuthenticationServicing = SupabaseSession()) {
        self.service = service
    }

    func restore() async {
        guard isRestoring else { return }
        defer { isRestoring = false }
        await perform {
            if try await self.service.restore() { self.identity = try await self.service.identity() }
        }
    }

    func handleCallback(_ url: URL) async {
        guard url.scheme == "crewcrate", url.host == "auth" else { return }
        if isBusy { pendingCallback = url; return }
        await perform {
            self.needsPasswordUpdate = try await self.service.acceptCallback(url)
            self.password = ""; self.confirmPassword = ""
            if !self.needsPasswordUpdate { self.identity = try await self.service.identity() }
        }
    }

    func saveNewPassword() async {
        guard password.count >= 8, password == confirmPassword else {
            notice = "Use at least 8 characters and make sure both passwords match."
            return
        }
        await perform {
            try await self.service.updatePassword(self.password)
            self.password = ""; self.confirmPassword = ""
            self.needsPasswordUpdate = false
            self.identity = try await self.service.identity()
        }
    }

    func signOut() async {
        await perform {
            self.identity = nil
            self.needsPasswordUpdate = false
            self.password = ""; self.confirmPassword = ""
            try await self.service.signOut()
        }
    }

    private func perform(_ action: () async throws -> Void) async {
        guard !isBusy else { return }
        isBusy = true
        defer {
            isBusy = false
            if let callback = pendingCallback {
                pendingCallback = nil
                Task { await self.handleCallback(callback) }
            }
        }
        do { try await action() }
        catch {
            notice = (error as? LocalizedError)?.errorDescription ?? "Couldn’t reach CrewCrate. Please try again."
        }
    }

    func login() async {
        guard validateEmail(), !password.isEmpty else {
            notice = "Enter your email and password."
            return
        }
        await perform {
            try await self.service.signIn(email: self.normalizedEmail, password: self.password)
            self.password = ""
            self.identity = try await self.service.identity()
        }
    }

    func createAccount() async {
        guard validateEmail() else {
            notice = "Enter a valid email address."
            return
        }
        guard password.count >= 8 else {
            notice = "Use a password with at least 8 characters."
            return
        }
        guard password == confirmPassword else {
            notice = "Your passwords do not match."
            return
        }
        await perform {
            let signedIn = try await self.service.signUp(email: self.normalizedEmail, password: self.password)
            self.password = ""; self.confirmPassword = ""
            if signedIn { self.identity = try await self.service.identity() }
            else { self.notice = "Check your email to confirm your account, then return here to log in." }
        }
    }

    func resetPassword() async {
        guard validateEmail() else {
            notice = "Enter a valid email address."
            return
        }
        await perform {
            try await self.service.recover(email: self.normalizedEmail)
            self.notice = "If an account exists for this email, a password reset link will arrive shortly."
        }
    }

    private var normalizedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func validateEmail() -> Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
}
