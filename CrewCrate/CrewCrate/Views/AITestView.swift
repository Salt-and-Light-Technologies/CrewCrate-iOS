import SwiftUI

struct AITestView: View {
    @State var viewModel: AITestViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTyping: Bool
    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack {
            VStack(spacing: 0) {
                Text("Practice conversation. Pretend you’re a customer. No real messages are sent.")
                    .font(.footnote).foregroundStyle(.secondary).padding()
                    .frame(maxWidth: .infinity).background(Color(.secondarySystemBackground))
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(viewModel.conversation?.messages ?? []) { message in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(message.role == "user" ? "You, as a customer" : (viewModel.conversation?.aiName ?? "AI assistant"))
                                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                    Text(message.text).textSelection(.enabled)
                                        .padding(14)
                                        .background(message.role == "user" ? Color(.tertiarySystemBackground) : AuthenticationStyle.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                                }
                                .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
                                .id(message.id)
                            }
                            if let decision = viewModel.conversation?.decisions.last {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(decision.label).font(.headline)
                                    DisclosureGroup("Why this happened") {
                                        Text(decision.reason).font(.subheadline)
                                        if !decision.handoffSummary.isEmpty { Text(decision.handoffSummary).font(.subheadline) }
                                    }
                                    if viewModel.conversation?.isActive == false {
                                        Text("This test has ended. Start a new test to try another scenario.").font(.footnote).foregroundStyle(.secondary)
                                    }
                                }.padding().frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                            }
                            if let error = viewModel.error {
                                Text(error).font(.subheadline).foregroundStyle(.red)
                                if viewModel.conversation == nil {
                                    Button("Retry starting test") { Task { await viewModel.start() } }
                                } else {
                                    if viewModel.canRetryReply {
                                        Button("Retry reply") { Task { await viewModel.retryReply() } }
                                    }
                                    Button("Refresh conversation") { Task { await viewModel.refresh() } }
                                }
                            }
                            if viewModel.isBusy { ProgressView("Waiting for the assistant…").frame(maxWidth: .infinity) }
                            Color.clear.frame(height: 1).id("latest")
                        }.padding()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: viewModel.conversation?.messages.count) { _, _ in
                        withAnimation { proxy.scrollTo("latest", anchor: .bottom) }
                    }
                }
                if viewModel.conversation?.isActive == true {
                    HStack(alignment: .bottom) {
                        TextField("Type a customer’s reply…", text: $viewModel.message, axis: .vertical)
                            .lineLimit(1...5).textFieldStyle(.roundedBorder).focused($isTyping)
                        Button { isTyping = false; Task { await viewModel.send() } } label: {
                            Image(systemName: "arrow.up.circle.fill").font(.title)
                        }.accessibilityLabel("Send test reply").disabled(!viewModel.canSend)
                    }.padding().disabled(viewModel.isBusy)
                }
            }
            .navigationTitle("Try your assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(viewModel.isBusy) }
                ToolbarItem(placement: .primaryAction) {
                    Button("Start over") { isTyping = false; Task { await viewModel.start() } }.disabled(viewModel.isBusy)
                }
            }
            .task { if viewModel.conversation == nil { await viewModel.start() } }
        }
        .tint(AuthenticationStyle.purple)
        .interactiveDismissDisabled(viewModel.isBusy)
    }
}
