import SwiftUI

struct DemoMessageThreadView: View {
    @State private var viewModel: DemoMessageThreadViewModel
    init(viewModel: DemoMessageThreadViewModel) { _viewModel = State(initialValue: viewModel) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.campaignTitle).font(.headline)
                    Text(viewModel.contact.phone).font(.subheadline)
                    Text(viewModel.contact.outcome).font(.subheadline)
                    Text("Demo conversation · No real messages sent").font(.caption)
                }.foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                ForEach(viewModel.contact.messages) { message in
                    HStack {
                        if message.isOutbound { Spacer(minLength: 32) }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(message.isOutbound ? "Emma · AI assistant" : viewModel.contact.name).font(.caption.bold())
                            Text(message.text)
                            Text(message.time).font(.caption).opacity(0.75)
                        }
                        .padding(14)
                        .foregroundStyle(message.isOutbound ? Color.white : Color.primary)
                        .background(message.isOutbound ? Color.indigo : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                        .textSelection(.enabled)
                        if !message.isOutbound { Spacer(minLength: 32) }
                    }
                }
            }.padding()
        }
        .navigationTitle(viewModel.contact.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
