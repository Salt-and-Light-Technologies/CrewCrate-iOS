import SwiftUI
import UniformTypeIdentifiers

struct LeadDemoNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Local lead demo", systemImage: "flask").font(.subheadline.bold()).foregroundStyle(.indigo)
            Text("These sample workspaces are not authenticated partner accounts. Imported contacts and activity stay in memory and reset when the app closes. Use the sample file to explore. No messages are sent.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}
