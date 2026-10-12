import Foundation
import Observation

@MainActor
@Observable
final class BusinessAccessViewModel {
    var draft = BusinessApplicationDraft()
    var application: BusinessApplication?
    var requests: [BusinessApplication] = []
    var businesses: [BusinessSummary] = []
    var isLoading = true
    var isBusy = false
    var error: String?
    var requestsError: String?
    var hasLoadedRequests = false
    var hasLoaded = false
    let isOwner: Bool
    private let service: any BusinessApplicationServicing

    init(isOwner: Bool, service: any BusinessApplicationServicing) {
        self.isOwner = isOwner
        self.service = service
    }

    func load() async {
        guard !isBusy else { return }
        isBusy = true
        error = nil
        defer { isBusy = false; isLoading = false }
        do {
            if isOwner {
                async let pending = service.pendingApplications()
                async let existing = service.businesses()
                // Inbox and business overview are independent. A broken overview must
                // never hide successfully loaded approval requests.
                do {
                    requests = try await pending
                    requestsError = nil
                    hasLoadedRequests = true
                } catch is CancellationError { }
                catch { requestsError = message(error) }
                do {
                    businesses = try await existing
                    hasLoaded = true
                } catch is CancellationError { }
                catch { self.error = message(error) }
            } else {
                let request = try await service.application()
                if let request, request.status != "approved" {
                    businesses = []
                } else {
                    businesses = try await service.businesses().filter { $0.access_approved == true }
                }
                application = request
            }
            if !isOwner { hasLoaded = true }
        } catch is CancellationError { }
        catch {
            if !isOwner { businesses = []; hasLoaded = false }
            self.error = message(error)
        }
    }

    func submit() async {
        guard !isBusy, draft.isComplete else { return }
        isBusy = true
        error = nil
        requestsError = nil
        defer { isBusy = false }
        do { application = try await service.submitApplication(draft) }
        catch { self.error = message(error) }
    }

    func decide(_ request: BusinessApplication, approve: Bool, note: String) async -> Bool {
        guard !isBusy else { return false }
        isBusy = true
        error = nil
        requestsError = nil
        defer { isBusy = false }
        do {
            _ = try await service.decide(request, approve: approve, note: note)
            requests.removeAll { $0.id == request.id }
            // A successful decision remains successful even if the following list reload fails.
            if approve {
                do { businesses = try await service.businesses() }
                catch { self.error = "Request approved. Refresh to reload your business list." }
            }
            return true
        } catch {
            self.error = message(error)
            requestsError = message(error)
            return false
        }
    }

    private func message(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Couldn’t reach CrewCrate. Please try again."
    }
}
