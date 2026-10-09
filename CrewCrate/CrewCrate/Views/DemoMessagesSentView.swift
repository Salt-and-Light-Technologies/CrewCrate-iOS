import SwiftUI

struct DemoMessagesSentView: View {
    @State private var viewModel: DemoMessagesSentViewModel
    init(viewModel: DemoMessagesSentViewModel) { _viewModel = State(initialValue: viewModel) }
    var body: some View {
        List {
            Section {
                Text(viewModel.campaign.title).font(.headline)
                LabeledContent("Messages sent · Demo", value: "\(viewModel.campaign.messagesSent)")
                Text("Three sample contacted users have conversation previews. These fictional threads illustrate the campaign experience.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Contacted users · Demo") {
                ForEach(viewModel.contacts) { contact in
                    NavigationLink { DemoMessageThreadView(viewModel: viewModel.thread(for: contact)) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(contact.name).font(.headline)
                            Text(contact.phone).font(.caption).foregroundStyle(.secondary)
                            Text(contact.outcome).font(.subheadline).foregroundStyle(.secondary)
                            if let message = contact.messages.last { Text(message.text).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                        }.padding(.vertical, 4)
                    }
                }
            }
        }.navigationTitle("Messages sent").navigationBarTitleDisplayMode(.inline)
    }
}
