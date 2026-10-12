import SwiftUI

struct SignupBusinessView: View {
    @Environment(AuthenticationViewModel.self) private var viewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        Group {
            if viewModel.signupComplete {
                AuthenticationLayout(title: "Approval required",
                                     subtitle: "Business access must be approved by the CrewCrate owner.") {
                    VStack(spacing: 20) {
                        Text(viewModel.signupNeedsEmailConfirmation
                            ? "Your login is created, but business access is not approved. Confirm your email, then log in to send your saved request for owner review."
                            : "Your login is created, but business access is not approved. Return to login to submit your saved request for owner review.")
                            .foregroundStyle(.secondary)
                        Text(viewModel.email).font(.headline).textSelection(.enabled)
                        Text("Use the back button to return to login.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            } else {
                AuthenticationLayout(title: "Tell us about your business", subtitle: "Step 2 of 2 · A few quick questions") {
                    VStack(spacing: 20) {
                        AuthenticationField(label: "Business name") {
                            TextField("e.g. Bob’s Roofing", text: $viewModel.signupBusiness.business_name)
                                .textContentType(.organizationName)
                        }
                        AuthenticationField(label: "Your name") {
                            TextField("First and last name", text: $viewModel.signupBusiness.contact_name)
                                .textContentType(.name)
                        }
                        AuthenticationField(label: "Business contact phone") {
                            TextField("Your phone number", text: $viewModel.signupBusiness.phone)
                                .keyboardType(.phonePad).textContentType(.telephoneNumber)
                        }
                        AuthenticationField(label: "How did you hear about CrewCrate? (optional)") {
                            TextField("A referral name or where you found us", text: $viewModel.signupBusiness.referral, axis: .vertical)
                                .lineLimit(2...4)
                        }
                        Text("Your login email will be your contact email. After email confirmation, your business request will await approval. Other businesses cannot see your information.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Create account") { Task { await viewModel.createAccount() } }
                            .buttonStyle(AuthenticationButtonStyle())
                            .disabled(!viewModel.signupBusiness.isComplete)
                    }
                }
            }
        }
        .navigationTitle("Your business")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(viewModel.isBusy)
        .navigationBarBackButtonHidden(viewModel.isBusy)
    }
}
