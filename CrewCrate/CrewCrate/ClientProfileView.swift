import SwiftUI
import SwiftData

struct ClientProfileView: View {
    @Environment(\.modelContext) private var context; @Bindable var client: Client
    @State private var action: QuickAction?; @State private var editing = false; @State private var profileCaptureSource: CaptureSource?; @State private var showPhotoActions = false
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 18) {
        HStack(spacing: 15) { Button { showPhotoActions = true } label: { ZStack(alignment: .bottomTrailing) { ClientAvatar(client: client, size: 62); Image(systemName: "camera.fill").font(.caption2.bold()).foregroundStyle(.white).padding(6).background(.indigo, in: Circle()).overlay { Circle().stroke(.background, lineWidth: 2) } } }.buttonStyle(.plain); VStack(alignment: .leading) { Text(client.name).font(.title2.bold()); Text(client.company.isEmpty ? "Client" : client.company).foregroundStyle(.secondary) }; Spacer(); Button { client.isFavorite.toggle() } label: { Image(systemName: client.isFavorite ? "star.fill" : "star").foregroundStyle(.yellow) } }
        if !client.phone.isEmpty || !client.email.isEmpty { DashboardWidget(title: "Contact", subtitle: client.address, icon: "person.crop.circle", accent: .indigo) { if !client.phone.isEmpty { CompactRow(title: client.phone, detail: "", symbol: "phone") }; if !client.email.isEmpty { CompactRow(title: client.email, detail: "", symbol: "envelope") } } }
        Text("Quick actions").font(.title3.bold()).padding(.top, 2)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
            ForEach(QuickAction.allCases.filter { $0 != .client }) { quick in
                Button { action = quick } label: {
                    VStack(spacing: 8) {
                        Image(systemName: quick.symbol).font(.title3)
                        Text(quick.title).font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
                    .glassCard()
                }
                .buttonStyle(.plain)
            }
        }
        if !client.media.isEmpty { DashboardWidget(title: "Media", subtitle: "Photos and videos", icon: "camera", accent: .pink) { ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(client.media.sorted { $0.createdAt > $1.createdAt }) { attachment in MediaAttachmentPreview(attachment: attachment).contextMenu { Button("Delete", systemImage: "trash", role: .destructive) { context.delete(attachment) } } } } } } }
        if !client.documents.isEmpty { DashboardWidget(title: "Estimates & Invoices", subtitle: "", icon: "doc.text", accent: .orange) { ForEach(client.documents.sorted { $0.updatedAt > $1.updatedAt }) { doc in HStack { VStack(alignment: .leading) { Text(doc.title).font(.subheadline.weight(.medium)); Text(doc.kind.rawValue.capitalized).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(Currency.format(doc.total)).font(.subheadline.bold()); StatusBadge(status: doc.status) } } } }
        if !client.tasks.isEmpty { DashboardWidget(title: "Tasks", subtitle: "Keep work moving", icon: "checkmark.circle", accent: .green) { ForEach(client.tasks.sorted { $0.dueDate < $1.dueDate }) { task in Button { task.isComplete.toggle(); ActivityLogger.log("Task \(task.isComplete ? "completed" : "reopened")", detail: task.title, type: "Task", status: task.isComplete ? .completed : .inProgress, client: client, in: context) } label: { HStack { Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle").foregroundStyle(task.isComplete ? .green : .secondary); Text(task.title).strikethrough(task.isComplete); Spacer(); Text(task.dueDate, style: .date).font(.caption).foregroundStyle(.secondary) } }.buttonStyle(.plain) } } }
        Text("Activity Feed").font(.title3.bold()).padding(.top, 4); if client.activities.isEmpty { EmptyState(symbol: "bolt", title: "No activity yet", detail: "New work for this client will appear here.") } else { ForEach(client.activities.sorted { $0.date > $1.date }) { ActivityCard(record: $0) } }
    }.padding() }.background(AppBackground()).navigationTitle("Client").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarTrailing) { Menu { Button("Edit client", systemImage: "pencil") { editing = true }; Button("New estimate", systemImage: "doc.text") { action = .estimate }; Button("New invoice", systemImage: "receipt") { action = .invoice } } label: { Image(systemName: "ellipsis.circle") } } }.sheet(item: $action) { QuickCreateSheet(action: $0, fixedClient: client).presentationDetents([.medium, .large]) }.sheet(isPresented: $editing) { ClientEditor(client: client).presentationDetents([.large]) }.confirmationDialog("Client photo", isPresented: $showPhotoActions) { Button("Take Photo", systemImage: "camera.fill") { profileCaptureSource = .camera }; Button("Choose from Library", systemImage: "photo.on.rectangle") { profileCaptureSource = .library }; if client.profileImageData != nil { Button("Remove Photo", systemImage: "trash", role: .destructive) { client.profileImageData = nil } } }.fullScreenCover(item: $profileCaptureSource) { source in ClientPhotoPicker(source: source, client: client) } }
}

struct ClientPhotoPicker: View { @Environment(\.dismiss) private var dismiss; let source: CaptureSource; @Bindable var client: Client; @State private var capturedMedia: CapturedMedia?
    var body: some View { CameraCapturePicker(source: source, allowsVideo: false, media: $capturedMedia).onChange(of: capturedMedia) { _, media in if let media { client.profileImageData = media.data; dismiss() } } }
}
