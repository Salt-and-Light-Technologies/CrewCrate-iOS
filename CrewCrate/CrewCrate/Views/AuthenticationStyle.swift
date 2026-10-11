import SwiftUI

enum AuthenticationStyle {
    static let purple = Color(red: 0.36, green: 0.22, blue: 0.70)
}

struct AuthenticationLayout<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image("CrateMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .padding(22)
                        .background(AuthenticationStyle.purple, in: RoundedRectangle(cornerRadius: 32))
                        .accessibilityLabel("CrewCrate logo")
                    Text("CrewCrate")
                        .font(.title2.weight(.bold))
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.largeTitle.weight(.bold))
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                content
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
        .tint(AuthenticationStyle.purple)
    }
}

struct AuthenticationField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline.weight(.semibold))
            content
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08)))
        }
    }
}

struct AuthenticationButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(isEnabled ? AuthenticationStyle.purple : Color.secondary, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
