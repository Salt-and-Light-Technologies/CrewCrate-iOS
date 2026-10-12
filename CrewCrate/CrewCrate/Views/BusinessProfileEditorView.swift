import SwiftUI

struct BusinessProfileEditorView: View {
    @State private var model: BusinessProfileEditorModel
    @State private var reloading = false
    @State private var closing = false
    @Environment(\.dismiss) private var dismiss
    init(business: BusinessSummary, service: any BusinessProfileServicing) {
        _model = State(initialValue: BusinessProfileEditorModel(business: business, service: service))
    }
    var body: some View {
        @Bindable var model = model
        Form {
            if !model.hasLoaded {
                if model.isBusy { ProgressView("Loading your business…") }
                if let error = model.error {
                    Text(error).foregroundStyle(.red)
                    Button("Try again") { Task { await model.load() } }
                }
            } else {
                Section {
                    Text("Give your assistant the right context.")
                    Text("This information is shared across your business’s campaigns.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("Business details") {
                    TextField("Business name", text: $model.fields.business_name)
                    TextField("Website (optional)", text: $model.fields.website)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Industry", text: $model.fields.industry)
                    TextField("Services or products", text: $model.fields.services, axis: .vertical).lineLimit(2...5)
                    TextField("Service area", text: $model.fields.service_area)
                }
                Section("Your assistant’s boundaries") {
                    TextField("What should it avoid promising?", text: $model.fields.ai_boundaries, axis: .vertical)
                        .lineLimit(3...6)
                    Text("For example: don’t quote prices or promise same-day service.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Time zone") {
                    BusinessTimeZonePicker(selection: $model.fields.time_zone)
                }
                Section {
                    Button("Save business information") { Task { await model.save() } }
                        .buttonStyle(AuthenticationButtonStyle()).disabled(!model.canSave)
                    Text("Changes may require business readiness to be reviewed again.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let error = model.error {
                        Text(error).foregroundStyle(.red)
                        Button("Reload saved information") { reloading = true }
                    }
                }
            }
        }
        .disabled(model.isBusy)
        .navigationTitle("Business information")
        .navigationBarBackButtonHidden(model.hasEdits || model.isBusy)
        .toolbar {
            if model.hasEdits {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { closing = true }.disabled(model.isBusy)
                }
            }
        }
        .confirmationDialog("Discard your changes?", isPresented: $closing, titleVisibility: .visible) {
            Button("Discard and go back", role: .destructive) { dismiss() }
        }
        .confirmationDialog("Reloading discards unsaved changes.", isPresented: $reloading, titleVisibility: .visible) {
            Button("Reload", role: .destructive) { Task { await model.load() } }
        }
        .alert("Business information saved", isPresented: $model.savedNotice) { Button("OK") { } }
        .task { if !model.hasLoaded { await model.load() } }
    }
}
