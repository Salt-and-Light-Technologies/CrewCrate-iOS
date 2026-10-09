//
//  CrewCrateApp.swift
//  CrewCrate
//
//  Created by James McDougall on 9/8/26.
//

import SwiftUI
import SwiftData

@main
struct CrewCrateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Client.self, ActivityRecord.self, Appointment.self, CRMNote.self, CRMTask.self, FinancialDocument.self, LineItem.self, MediaAttachment.self])
    }
}
