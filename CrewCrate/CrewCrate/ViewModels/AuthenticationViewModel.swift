import Foundation
import Observation

@Observable
final class AuthenticationViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var notice: String?

    func login() {
        guard validateEmail(), !password.isEmpty else {
            notice = "Enter your email and password."
            return
        }
        notice = "Login is not connected yet. Your information has not been sent."
    }

    func createAccount() {
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
        notice = "Account creation is not connected yet. Your information has not been sent."
    }

    func resetPassword() {
        guard validateEmail() else {
            notice = "Enter a valid email address."
            return
        }
        notice = "Password recovery is not connected yet. No reset email has been sent."
    }

    private func validateEmail() -> Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil
    }
}
