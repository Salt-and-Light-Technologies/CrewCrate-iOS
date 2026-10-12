import SwiftUI

struct BusinessTimeZonePicker: View {
    @Binding var selection: String
    private let choices = [
        ("Eastern", "America/New_York"), ("Central", "America/Chicago"),
        ("Mountain", "America/Denver"), ("Arizona", "America/Phoenix"),
        ("Pacific", "America/Los_Angeles"), ("Alaska", "America/Anchorage"),
        ("Hawaii", "Pacific/Honolulu")
    ]
    var body: some View {
        Picker("Business time zone", selection: $selection) {
            Text("Choose a time zone").tag("")
            ForEach(choices, id: \.1) { choice in Text(choice.0).tag(choice.1) }
            if !selection.isEmpty && !choices.contains(where: { $0.1 == selection }) {
                Text("Saved: \(selection.replacingOccurrences(of: "_", with: " "))").tag(selection)
            }
        }
    }
}
