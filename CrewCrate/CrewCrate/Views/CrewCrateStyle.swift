import SwiftUI

/// Shared, readable controls for the signed-in flows.
struct CrewPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 48).padding(.horizontal, 16)
            .foregroundStyle(.white)
            .background(isEnabled ? AuthenticationStyle.purple : Color.secondary, in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct CrewTaskLabel: View {
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(AuthenticationStyle.purple)
                .frame(width: 32).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 10).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CrewStepHeader: View {
    let step: Int
    let title: String
    let explanation: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Step \(step + 1) of 4").font(.subheadline.weight(.semibold)).foregroundStyle(AuthenticationStyle.purple)
            Text(title).font(.title2.bold())
            Text(explanation).font(.body).foregroundStyle(.secondary)
        }.padding(.vertical, 8).accessibilityElement(children: .combine)
    }
}
