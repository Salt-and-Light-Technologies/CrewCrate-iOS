import SwiftUI

struct MessagingBoundaryNotice: View {
    let isDemo: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Messaging not connected", systemImage: "message.badge.filled.fill").font(.headline).foregroundStyle(.indigo)
            Text("Plan and prepare campaigns yourself. No owner approval is required for each campaign. Sending, scheduled delivery and incoming SMS are disabled.").font(.subheadline)
            if isDemo { Text("Local demo records reset on app restart. Sample permissions are examples, not evidence for real outreach.").font(.caption).foregroundStyle(.secondary) }
        }.padding(.vertical, 4)
    }
}
