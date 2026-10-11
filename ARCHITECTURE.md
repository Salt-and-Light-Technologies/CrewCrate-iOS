# CrewCrate starter architecture

App/CrewCrateApp.swift defines the SwiftUI application and opens Views/ContentView.swift. ContentView displays the standard Hello, world! starter UI. There is no feature state requiring a view-model or data model yet.

All previous feature source is retained outside the Xcode filesystem-synchronized source group in LegacyReference/BeforeFreshStart-20261011. The existing Views/LaunchScreen.storyboard and asset catalog remain active and unchanged.

Add future features using strict MVVM, Observation and injected async services when needed. The app currently performs no authentication, network calls or persisted-data access.
