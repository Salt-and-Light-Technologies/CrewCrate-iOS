import SwiftUI

@main
struct CrewCrateApp: App {
    @State private var session = AppDependencies.makeSession()
    var body: some Scene {
        WindowGroup { ContentView(session: session) }
    }
}
