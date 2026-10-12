import Foundation
import Observation
import UIKit
import UserNotifications

@MainActor @Observable final class WorkerPushState {
    static let shared = WorkerPushState()
    var deviceToken: String?
    var openNotificationID: UUID?
    var refreshID = UUID()
    var unread = 0
    var foregroundBanner: WorkerAlert?
    private var seenAlerts = Set<UUID>()
    private var hasLoadedAlerts = false
    private var refreshingAlerts = false
    var registrationError: String?
    private var registeredToken: String?
    private var registrationTask: Task<Void, Error>?
    private var signingOut = false
    private var generation = 0

    func activate() { signingOut = false }

    func refreshAlerts(service: any WorkerServicing) async {
        guard !refreshingAlerts, !signingOut else { return }
        let requestGeneration = generation
        refreshingAlerts = true
        defer { refreshingAlerts = false }
        do {
            let alerts = try await service.workerAlerts()
            guard requestGeneration == generation, !signingOut else { return }
            if hasLoadedAlerts {
                foregroundBanner = alerts.first { !$0.read && !seenAlerts.contains($0.id) } ?? foregroundBanner
            }
            if let banner = foregroundBanner, !alerts.contains(where: { $0.id == banner.id && !$0.read }) {
                foregroundBanner = nil
            }
            seenAlerts.formUnion(alerts.map(\.id))
            hasLoadedAlerts = true
            unread = alerts.filter { !$0.read }.count
            try? await UNUserNotificationCenter.current().setBadgeCount(unread)
        } catch { registrationError = error.localizedDescription }
    }
    func enable(service: any WorkerServicing) async throws -> String {
        let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        guard allowed else { return "Notifications are off. You can enable them in device Settings. Lead alerts still appear here." }
        UIApplication.shared.registerForRemoteNotifications()
        try await register(service: service)
        return "Device permission is enabled. Push delivery also requires the CrewCrate server and Apple setup."
    }
    func restoreRegistration(service: any WorkerServicing) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
            await syncRegistration(service: service)
        }
    }
    func syncRegistration(service: any WorkerServicing) async {
        do { try await register(service: service) }
        catch { registrationError = error.localizedDescription }
    }
    private func register(service: any WorkerServicing) async throws {
        guard !signingOut else { return }
        if let registrationTask { try await registrationTask.value; return }
        guard let deviceToken, deviceToken != registeredToken else { return }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        let task = Task { try await service.registerWorkerDevice(token: deviceToken, environment: environment) }
        registrationTask = task
        defer { registrationTask = nil }
        try await task.value
        if !signingOut { registeredToken = deviceToken }
        registrationError = nil
    }
    func signOut(service: any WorkerServicing) async throws {
        signingOut = true
        generation += 1
        do {
            if let registrationTask { _ = try? await registrationTask.value }
            if let token = registeredToken ?? deviceToken { try await service.unregisterWorkerDevice(token: token) }
        } catch { signingOut = false; throw error }
        registeredToken = nil
        openNotificationID = nil
        unread = 0
        foregroundBanner = nil
        seenAlerts = []; hasLoadedAlerts = false
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

// UIKit is limited to Apple's remote notification registration/delegate bridge.
final class WorkerNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in WorkerPushState.shared.deviceToken = token }
    }
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in WorkerPushState.shared.registrationError = message }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // No system banner or sound in foreground. SwiftUI refreshes its small notice.
        completionHandler([])
        Task { @MainActor in WorkerPushState.shared.refreshID = UUID() }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        let raw = response.notification.request.content.userInfo["notification_id"] as? String
        let id = raw.flatMap(UUID.init(uuidString:))
        Task { @MainActor in
            WorkerPushState.shared.openNotificationID = id
            WorkerPushState.shared.refreshID = UUID()
        }
        completionHandler()
    }
}
