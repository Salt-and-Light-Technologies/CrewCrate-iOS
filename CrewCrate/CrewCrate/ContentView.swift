//
//  ContentView.swift
//  CrewCrate
//
//  Created by James McDougall on 9/8/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Client.lastActivityAt, order: .reverse) private var clients: [Client]
    @State private var selectedTab = AppTab.dashboard
    @State private var quickAction: QuickAction?
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(quickAction: $quickAction).tabItem { Label("Dashboard", systemImage: selectedTab == .dashboard ? "square.grid.2x2.fill" : "square.grid.2x2") }.tag(AppTab.dashboard)
            ClientsView(quickAction: $quickAction).tabItem { Label("Clients", systemImage: selectedTab == .clients ? "person.2.fill" : "person.2") }.tag(AppTab.clients)
            ActivityView().tabItem { Label("Activity", systemImage: selectedTab == .activity ? "clipboard.fill" : "clipboard") }.tag(AppTab.activity)
            CalendarView(quickAction: $quickAction).tabItem { Label("Calendar", systemImage: selectedTab == .calendar ? "calendar.circle.fill" : "calendar") }.tag(AppTab.calendar)
            MoreView().tabItem { Label("More", systemImage: selectedTab == .more ? "ellipsis.circle.fill" : "ellipsis.circle") }.tag(AppTab.more)
        }
        .tint(.indigo)
        .environment(\.symbolVariants, .none)
        .task { SeedData.installIfNeeded(in: modelContext, existingClients: clients) }
        .sheet(item: $quickAction) { QuickCreateSheet(action: $0).presentationDetents([.medium, .large]) }
    }
}
enum AppTab: Hashable { case dashboard, clients, activity, calendar, more }
enum QuickAction: String, Identifiable, CaseIterable { case client, estimate, invoice, appointment, note, task, media; var id: String { rawValue }; var title: String { rawValue.capitalized }; var symbol: String { switch self { case .client: "person.badge.plus"; case .estimate: "doc.text"; case .invoice: "receipt"; case .appointment: "calendar.badge.plus"; case .note: "note.text"; case .task: "checkmark.circle"; case .media: "camera.fill" } } }

struct DashboardView: View {
    @Query(sort: \Appointment.startDate) private var appointments: [Appointment]
    @Query(sort: \FinancialDocument.updatedAt, order: .reverse) private var documents: [FinancialDocument]
    @Query(sort: \ActivityRecord.date, order: .reverse) private var activity: [ActivityRecord]
    @Binding var quickAction: QuickAction?
    private var today: [Appointment] { appointments.filter { Calendar.current.isDateInToday($0.startDate) } }
    private var unpaid: [FinancialDocument] { documents.filter { $0.kind == .invoice && $0.status != .paid } }
    var body: some View { NavigationStack { ScrollView { VStack(alignment: .leading, spacing: 20) {
        HStack(alignment: .top) { VStack(alignment: .leading, spacing: 5) { Text("Good morning").font(.title.bold()); Text(Date.now.formatted(date: .complete, time: .omitted)).foregroundStyle(.secondary) }; Spacer(); Image("CrateMark").resizable().scaledToFit().frame(width: 52, height: 52).accessibilityLabel("CrewCrate") }
        DashboardWidget(title: "Today’s Schedule", subtitle: today.isEmpty ? "Nothing scheduled yet" : "\(today.count) item\(today.count == 1 ? "" : "s") need your attention", icon: "calendar", accent: .blue) { ForEach(today.prefix(3)) { CompactRow(title: $0.title, detail: $0.startDate.formatted(date: .omitted, time: .shortened), symbol: "clock") } }
        HStack(spacing: 12) { MetricCard(value: Currency.format(unpaid.reduce(0) { $0 + $1.total }), label: "Outstanding", symbol: "dollarsign.circle", color: .orange); MetricCard(value: "\(documents.filter { $0.kind == .estimate && $0.status != .approved }.count)", label: "Open estimates", symbol: "doc.text", color: .purple) }
        DashboardWidget(title: "Recent Activity", subtitle: "Your team’s latest updates", icon: "bolt.fill", accent: .mint) { ForEach(activity.prefix(3)) { ActivityRow(record: $0) } }
        Text("Quick actions").font(.title3.bold()).padding(.horizontal, 4)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) { ForEach(QuickAction.allCases) { action in Button { quickAction = action } label: { VStack(spacing: 9) { Image(systemName: action.symbol).font(.title3); Text(action.title).font(.caption.weight(.semibold)) }.frame(maxWidth: .infinity).frame(height: 78).glassCard() }.buttonStyle(.plain) } }
    }.padding() }.background(AppBackground()).navigationBarTitleDisplayMode(.inline) } }
}

struct ClientsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Client.lastActivityAt, order: .reverse) private var clients: [Client]
    @Binding var quickAction: QuickAction?; @State private var search = ""; @State private var favoritesOnly = false; @State private var sortByName = false
    private var filtered: [Client] { clients.filter { (!favoritesOnly || $0.isFavorite) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.company.localizedCaseInsensitiveContains(search)) }.sorted { sortByName ? $0.name < $1.name : $0.lastActivityAt > $1.lastActivityAt } }
    var body: some View { NavigationStack { Group { if filtered.isEmpty { EmptyState(symbol: "person.2", title: "No clients found", detail: "Add a client to start building your crew.") } else { List { ForEach(filtered) { client in NavigationLink(value: client) { ClientRow(client: client) }.listRowBackground(Color.clear) }.onDelete { offsets in offsets.forEach { context.delete(filtered[$0]) } } }.scrollContentBackground(.hidden) } }.background(AppBackground()).navigationTitle("Clients").searchable(text: $search, prompt: "Search clients").toolbar { ToolbarItem(placement: .topBarLeading) { Menu { Toggle("Favorites only", isOn: $favoritesOnly); Toggle("Sort by name", isOn: $sortByName) } label: { Image(systemName: "line.3.horizontal.decrease.circle") } }; ToolbarItem(placement: .topBarTrailing) { Button { quickAction = .client } label: { Image(systemName: "plus") } } }.navigationDestination(for: Client.self) { ClientProfileView(client: $0) } } }
}

struct ActivityView: View { @Query(sort: \ActivityRecord.date, order: .reverse) private var records: [ActivityRecord]; @State private var search = ""; @State private var status: ActivityStatus?; private var filtered: [ActivityRecord] { records.filter { (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.employee.localizedCaseInsensitiveContains(search) || $0.client?.name.localizedCaseInsensitiveContains(search) == true) && (status == nil || $0.status == status) } }; var body: some View { NavigationStack { List { Section { ScrollView(.horizontal, showsIndicators: false) { HStack { FilterChip(title: "All", active: status == nil) { status = nil }; ForEach(ActivityStatus.allCases, id: \.self) { item in FilterChip(title: item.title, active: status == item) { status = item } } }.padding(.horizontal, 2) }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear) }; ForEach(filtered) { ActivityCard(record: $0) } }.listStyle(.plain).scrollContentBackground(.hidden).background(AppBackground()).navigationTitle("Activity").searchable(text: $search, prompt: "Search activity") } } }
struct CalendarView: View { @Environment(\.modelContext) private var context; @Query(sort: \Appointment.startDate) private var appointments: [Appointment]; @Query(sort: \ActivityRecord.date, order: .reverse) private var activities: [ActivityRecord]; @Binding var quickAction: QuickAction?; @State private var date = Date.now; @State private var editingAppointment: Appointment?; var selected: [Appointment] { appointments.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) } }; var body: some View { NavigationStack { List { Section { DatePicker("", selection: $date, displayedComponents: .date).datePickerStyle(.graphical).padding(.vertical, 4) }; Section(date.formatted(date: .complete, time: .omitted)) { if selected.isEmpty { ContentUnavailableView("No events", systemImage: "calendar.badge.exclamationmark", description: Text("Your day is open.")) }; ForEach(selected) { appointment in AppointmentRow(appointment: appointment).contentShape(Rectangle()).onTapGesture { editingAppointment = appointment }.contextMenu { Button("Edit", systemImage: "pencil") { editingAppointment = appointment }; Button("Delete", systemImage: "trash", role: .destructive) { delete(appointment) } }.swipeActions { Button("Delete", systemImage: "trash", role: .destructive) { delete(appointment) }; Button("Edit", systemImage: "pencil") { editingAppointment = appointment }.tint(.indigo) } } } }.scrollContentBackground(.hidden).background(AppBackground()).navigationTitle("Calendar").toolbar { Button { quickAction = .appointment } label: { Image(systemName: "plus") } }.sheet(item: $editingAppointment) { AppointmentEditor(appointment: $0, activities: activities).presentationDetents([.large]) } } }
    private func delete(_ appointment: Appointment) { activities.filter { $0.relatedAppointmentID == appointment.id || ($0.type == "Appointment" && $0.client?.id == appointment.client?.id && $0.detail.localizedCaseInsensitiveContains(appointment.title)) }.forEach { context.delete($0) }; context.delete(appointment) }
}
struct MoreView: View { var body: some View { NavigationStack { List { Section("Workspace") { Label("Team members", systemImage: "person.3"); Label("Company settings", systemImage: "building.2") }; Section("Coming soon") { Label("Payments", systemImage: "creditcard"); Label("Reports", systemImage: "chart.bar"); Label("Messages", systemImage: "message") } }.scrollContentBackground(.hidden).background(AppBackground()).navigationTitle("More") } } }

#Preview { ContentView().modelContainer(for: [Client.self, ActivityRecord.self, Appointment.self, CRMNote.self, CRMTask.self, FinancialDocument.self, LineItem.self, MediaAttachment.self], inMemory: true) }
