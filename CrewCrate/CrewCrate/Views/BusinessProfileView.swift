import SwiftUI

struct BusinessProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: BusinessViewModel
    var onSaved: (() -> Void)?
    var body: some View {
        @Bindable var viewModel = viewModel
        Form {
            if viewModel.workspaces.count > 1 {
                Section("Business") {
                    Picker("Select business", selection: Binding(get: { viewModel.selectedID }, set: { viewModel.select($0) })) {
                        ForEach(viewModel.workspaces) { business in
                            Text(business.onboarding.business_name).tag(Optional(business.id))
                        }
                    }
                }
            }
            Section {
                Text("Tell your assistant about your business.").font(.headline)
                Text("These details help it give accurate answers.").foregroundStyle(.secondary)
            }
            Section("Your business") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Business name").font(.subheadline.weight(.semibold))
                    TextField("e.g. River Street Plumbing", text: $viewModel.details.business_name)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("What do you sell or offer?").font(.subheadline.weight(.semibold))
                    TextField("Describe your products or services", text: $viewModel.details.services, axis: .vertical).lineLimit(2...6)
                }
                TextField("Where do you serve customers?", text: $viewModel.details.service_area)
            }.disabled(viewModel.isBusy || !viewModel.hasLoaded)
            Section {
                DisclosureGroup("More business details") {
                    TextField("Industry", text: $viewModel.details.industry)
                    TextField("Website", text: $viewModel.details.website)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Picker("Time zone", selection: $viewModel.details.time_zone) {
                        ForEach(Array(Set(TimeZone.knownTimeZoneIdentifiers + [viewModel.details.time_zone])).sorted(), id: \.self) { zone in
                            Text(zone.replacingOccurrences(of: "_", with: " ")).tag(zone)
                        }
                    }
                    TextField("Anything your assistant should avoid?", text: $viewModel.details.ai_boundaries, axis: .vertical).lineLimit(2...6)
                }
            }.disabled(viewModel.isBusy || !viewModel.hasLoaded)
            Section {
                if viewModel.saved { Text("Business information saved.").foregroundStyle(.green) }
                if let error = viewModel.error {
                    Text(error).foregroundStyle(.red)
                    Button("Reload business information") { Task { await viewModel.load() } }
                }
            }
        }
        .navigationTitle(viewModel.selectedID == nil ? "Set up your business" : "Business profile")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if viewModel.details.business_name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Text("Enter your business name to continue.").font(.footnote).foregroundStyle(.secondary) }
                Button("Save business") { Task { if await viewModel.save() { onSaved?(); dismiss() } } }
                    .buttonStyle(CrewPrimaryButtonStyle()).disabled(!viewModel.canSave)
            }.padding().background(.regularMaterial)
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay { if viewModel.isBusy { ProgressView() } }
        .task { if !viewModel.hasLoaded { await viewModel.load() } }
    }
}
