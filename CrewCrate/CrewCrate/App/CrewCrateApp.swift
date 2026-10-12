import SwiftUI

@main
struct CrewCrateApp: App {
    @UIApplicationDelegateAdaptor(WorkerNotificationDelegate.self) private var notificationDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
