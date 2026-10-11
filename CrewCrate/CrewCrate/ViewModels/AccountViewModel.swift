import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class AccountViewModel {
    var firstName = ""
    var lastName = ""
    var email = ""
    var pendingEmail: String?
    var photoData: Data?
    var selectedPhoto: PhotosPickerItem?
    var isBusy = false
    var isLoading = false
    var hasLoaded = false
    var notice: String?
    private var currentEmail = ""
    private let service: any AccountServicing
    private let userID: UUID
    private let photos: ProfilePhotoStore

    init(service: any AccountServicing, userID: UUID, photos: ProfilePhotoStore? = nil) {
        self.service = service; self.userID = userID; self.photos = photos ?? ProfilePhotoStore()
    }
    func load() async {
        guard !isBusy else { return }
        isBusy = true; isLoading = true
        defer { isBusy = false; isLoading = false }
        do {
            let profile = try await service.profile()
            guard profile.id == userID else { throw AuthError.response }
            firstName = profile.metadata?.firstName ?? ""
            lastName = profile.metadata?.lastName ?? ""
            email = profile.email ?? ""; currentEmail = email
            pendingEmail = profile.newEmail.flatMap { $0.isEmpty ? nil : $0 }
            photoData = try photos.load(for: userID)
            hasLoaded = true
        } catch { notice = error.localizedDescription }
    }
    func save() async {
        guard !isBusy, hasLoaded else { return }
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard address.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) != nil else {
            notice = "Enter a valid email address."; return
        }
        isBusy = true; defer { isBusy = false }
        do {
            let changedEmail = address.caseInsensitiveCompare(currentEmail) != .orderedSame
            let profile = try await service.updateProfile(firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines), lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines), email: changedEmail ? address : nil)
            firstName = profile.metadata?.firstName ?? ""; lastName = profile.metadata?.lastName ?? ""
            email = profile.email ?? currentEmail; currentEmail = email
            pendingEmail = profile.newEmail.flatMap { $0.isEmpty ? nil : $0 }
            notice = changedEmail && email.caseInsensitiveCompare(address) != .orderedSame
                ? "Profile saved. Check your current and new inboxes to confirm your email change."
                : "Your profile has been saved."
        } catch { notice = error.localizedDescription }
    }
    func changePhoto() async {
        guard let item = selectedPhoto, !isBusy else { return }
        isBusy = true; defer { isBusy = false; selectedPhoto = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw AuthenticationFailure(message: "This photo could not be opened.")
            }
            photoData = try photos.save(data, for: userID)
        } catch { notice = error.localizedDescription }
    }
}
