import Foundation
import Observation

@MainActor
@Observable
final class AuthenticationViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var signingInAsOwner = false
    var signupBusiness = BusinessApplicationDraft()
    var signupComplete = false
    var signupNeedsEmailConfirmation = true
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
            self.signupBusiness = BusinessApplicationDraft()
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
            let identity = try await self.service.identity()
            if self.signingInAsOwner && !identity.isOwner {
                try await self.service.signOut()
                throw AuthenticationFailure(message: "This account does not have platform owner access. Choose business sign-in to continue.")
            }
            self.identity = identity
        }
    }

    func validateAccountDetails() -> Bool {
        guard validateEmail() else {
            notice = "Enter a valid email address."
            return false
        }
        guard password.count >= 8 else {
            notice = "Use a password with at least 8 characters."
            return false
        }
        guard password == confirmPassword else {
            notice = "Your passwords do not match."
            return false
        }
        return true
    }

    func createAccount() async {
        guard validateAccountDetails() else { return }
        signupBusiness.email = normalizedEmail
        guard signupBusiness.isComplete else {
            notice = "Enter your business name, your name and a valid contact phone number."
            return
        }
        await perform {
            let signedIn = try await self.service.signUp(email: self.normalizedEmail, password: self.password, business: self.signupBusiness)
            self.password = ""; self.confirmPassword = ""
            self.signupBusiness = BusinessApplicationDraft()
            self.signupNeedsEmailConfirmation = !signedIn
            self.signupComplete = true
            if signedIn { self.identity = try await self.service.identity() }
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
