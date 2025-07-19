//
//  TodoViews.swift
//  ToDoApp
//
//  Created by Martin Hrbáček on 16.07.2025.
//

import SwiftUI
import CoreData

// MARK: - Main Content View
struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.todoRepository) private var repository
    @StateObject private var viewModel: ContentViewModel
    @StateObject private var cloudKitStatusManager = CloudKitStatusManager.shared
    @State private var showingCloudKitInfo = false
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TodoTask.createdAt, ascending: false),
            NSSortDescriptor(keyPath: \TodoTask.dueDate, ascending: true)
        ]
    ) private var tasks: FetchedResults<TodoTask>
    
    init() {
        self._viewModel = StateObject(wrappedValue: DIContainer.shared.makeContentViewModel())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            CustomHeaderView(
                selectedTheme: $viewModel.selectedTheme,
                onInfo: { showingCloudKitInfo = true },
                onSync: { Task { try? await repository.syncWithCloudKit() } },
                onAdd: { viewModel.showingAddTask = true },
                isCloudKitAvailable: cloudKitStatusManager.isCloudKitAvailable
            )
            .background(viewModel.selectedTheme.accentColor.opacity(0.1))
            .animation(.easeInOut(duration: 0.6), value: viewModel.selectedTheme)
            
            // CloudKit Status Bar
            CloudKitStatusBar()
                .background(viewModel.selectedTheme.accentColor.opacity(0.1))
                .animation(.easeInOut(duration: 0.6), value: viewModel.selectedTheme)
            
            // Statistiky
            StatsView(statistics: viewModel.statistics(from: Array(tasks)))
            
            // Filtry
            FilterBarView(selectedFilter: $viewModel.selectedFilter)
            
            // Seznam úkolů
            TaskListView(
                tasks: viewModel.filteredTasks(from: Array(tasks)),
                onToggle: { task in viewModel.toggleTask(task) },
                onDelete: viewModel.deleteTask,
                onEdit: viewModel.editTask,
                theme: viewModel.selectedTheme
            )
            Spacer()
        }
        .background(viewModel.selectedTheme.backgroundColor)
        .preferredColorScheme(viewModel.selectedTheme.colorScheme)
        .environment(\.selectedTheme, viewModel.selectedTheme)
        .animation(.easeInOut(duration: 0.6), value: viewModel.selectedTheme)
        .sheet(isPresented: $viewModel.showingAddTask) {
            AddTaskView(theme: viewModel.selectedTheme)
        }
        .sheet(isPresented: $viewModel.showingEditTask) {
            if let task = viewModel.taskToEdit {
                EditTaskView(task: task, theme: viewModel.selectedTheme)
            }
        }
        .sheet(isPresented: $showingCloudKitInfo) {
            CloudKitInfoView(theme: viewModel.selectedTheme)
        }
        .onAppear {
            TaskExpirationManager.shared.checkAndMarkExpiredTasks()
        }
    }
}

// Custom Header View
struct CustomHeaderView: View {
    @Binding var selectedTheme: AppTheme
    var onInfo: () -> Void
    var onSync: () -> Void
    var onAdd: () -> Void
    var isCloudKitAvailable: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Theme toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        selectedTheme = selectedTheme == .default ? .dark : .default
                    }
                }) {
                    Image(systemName: selectedTheme == .default ? "moon.fill" : "sun.max.fill")
                        .foregroundColor(selectedTheme.accentColor)
                        .font(.title2)
                }
                .accessibilityLabel(selectedTheme == .default ? "Přepnout na tmavý režim" : "Přepnout na světlý režim")
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .foregroundColor(selectedTheme.accentColor)
                            .font(.title2)
                    }
                    Button(action: onSync) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(selectedTheme.accentColor)
                            .font(.title2)
                    }
                    .disabled(!isCloudKitAvailable)
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .foregroundColor(selectedTheme.accentColor)
                            .font(.title2)
                    }
                }
            }
            
            Text("Moje úkoly")
                .font(.largeTitle).bold()
                .foregroundColor(selectedTheme.textColor)
                .animation(.easeInOut(duration: 0.6), value: selectedTheme)
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - CloudKit Status Bar
struct CloudKitStatusBar: View {
    @StateObject private var cloudKitStatusManager = CloudKitStatusManager.shared
    @Environment(\.selectedTheme) private var theme
    
    var body: some View {
        if !cloudKitStatusManager.isCloudKitAvailable {
            HStack {
                Image(systemName: "icloud.slash")
                    .foregroundColor(theme.expiredColor)
                Text("iCloud není dostupný - úkoly se nesynchronizují")
                    .font(.caption)
                    .foregroundColor(theme.expiredColor)
                Spacer()
                Button("Nastavení") {
                    // Otevřít nastavení iCloud
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.caption)
                .foregroundColor(theme.accentColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(theme.expiredColor.opacity(0.1))
        } else if cloudKitStatusManager.syncStatus == .syncing {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                    .foregroundColor(theme.accentColor)
                Text(cloudKitStatusManager.syncStatus.description)
                    .font(.caption)
                    .foregroundColor(theme.accentColor)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(theme.accentColor.opacity(0.1))
        } else if case .error(let message) = cloudKitStatusManager.syncStatus {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(theme.expiredColor)
                Text(message)
                    .font(.caption)
                    .foregroundColor(theme.expiredColor)
                Spacer()
                Button("Zkusit znovu") {
                    cloudKitStatusManager.checkCloudKitStatus()
                }
                .font(.caption)
                .foregroundColor(theme.accentColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(theme.expiredColor.opacity(0.1))
        }
    }
}

// MARK: - CloudKit Info View
struct CloudKitInfoView: View {
    @Environment(\.dismiss) private var dismiss
    let theme: AppTheme
    @StateObject private var cloudKitStatusManager = CloudKitStatusManager.shared
    
    init(theme: AppTheme) {
        self.theme = theme
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status sekce
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Stav synchronizace")
                            .font(.headline)
                            .foregroundColor(theme.textColor)
                        
                        HStack {
                            Image(systemName: cloudKitStatusManager.isCloudKitAvailable ? "icloud" : "icloud.slash")
                                .foregroundColor(cloudKitStatusManager.isCloudKitAvailable ? theme.accentColor : theme.expiredColor)
                            Text(cloudKitStatusManager.isCloudKitAvailable ? "iCloud je dostupný" : "iCloud není dostupný")
                                .foregroundColor(theme.textColor)
                        }
                        
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(theme.accentColor)
                            Text(cloudKitStatusManager.syncStatus.description)
                                .foregroundColor(theme.textColor)
                        }
                    }
                    .padding()
                    .background(theme.taskRowBackground)
                    .cornerRadius(12)
                    
                    // Informace sekce
                    VStack(alignment: .leading, spacing: 12) {
                        Text("O synchronizaci")
                            .font(.headline)
                            .foregroundColor(theme.textColor)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(icon: "icloud", text: "Úkoly se automaticky synchronizují mezi všemi zařízeními", theme: theme)
                            InfoRow(icon: "wifi", text: "Synchronizace probíhá přes internet", theme: theme)
                            InfoRow(icon: "clock", text: "Změny se projeví během několika sekund", theme: theme)
                            InfoRow(icon: "exclamationmark.triangle", text: "Aplikace funguje i offline", theme: theme)
                        }
                    }
                    .padding()
                    .background(theme.taskRowBackground)
                    .cornerRadius(12)
                    
                    // Nastavení sekce
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nastavení")
                            .font(.headline)
                            .foregroundColor(theme.textColor)
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                    .foregroundColor(theme.accentColor)
                                Text("Otevřít nastavení iCloud")
                                    .foregroundColor(theme.accentColor)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(theme.accentColor)
                            }
                        }
                        .padding()
                        .background(theme.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(theme.taskRowBackground)
                    .cornerRadius(12)
                }
                .padding()
            }
            .background(theme.backgroundColor)
            .navigationTitle("Synchronizace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Zavřít") { dismiss() }
                        .foregroundColor(theme.accentColor)
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
    }
}

struct InfoRow: View {
    let icon: String
    let text: String
    let theme: AppTheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(theme.accentColor)
                .frame(width: 20)
            Text(text)
                .foregroundColor(theme.textColor)
                .font(.subheadline)
            Spacer()
        }
    }
}

// MARK: - Statistics View
struct StatsView: View {
    let statistics: TaskStatistics
    
    var body: some View {
        HStack {
            StatCard(title: "Celkem", value: "\(statistics.totalCount)", color: .blue)
            StatCard(title: "Hotovo", value: "\(statistics.completedCount)", color: .green)
            StatCard(title: "Aktivní", value: "\(statistics.activeCount)", color: .orange)
            StatCard(title: "Expirované", value: "\(statistics.expiredCount)", color: .red)
        }
        .padding(.horizontal)
        .padding(.top)

    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    @Environment(\.selectedTheme) private var theme
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(theme.accentColor) // Vždy tmavě oranžová pro čísla
            
            Text(title)
                .font(.caption)
                .foregroundColor(theme.secondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(theme.taskRowBackground)
        .cornerRadius(8)
    }
}

// MARK: - Filter Bar View
struct FilterBarView: View {
    @Binding var selectedFilter: TaskFilter
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

struct FilterButton: View {
    let filter: TaskFilter
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.selectedTheme) private var theme
    
    var body: some View {
        Button(action: action) {
            Text(filter.rawValue)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                        .background(isSelected ? theme.accentColor : theme.taskRowBackground)
        .foregroundColor(isSelected ? .white : theme.textColor)
        .cornerRadius(20)
        }
    }
}

// MARK: - Theme Toggle View
struct ThemeToggleView: View {
    @Binding var selectedTheme: AppTheme
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.5)) {
                selectedTheme = selectedTheme == .default ? .dark : .default
            }
        }) {
            Image(systemName: selectedTheme == .default ? "moon.fill" : "sun.max.fill")
                .foregroundColor(selectedTheme.accentColor)
                .font(.body)
        }
        .accessibilityLabel(selectedTheme == .default ? "Přepnout na tmavý režim" : "Přepnout na světlý režim")
    }
}

// MARK: - Task List View
struct TaskListView: View {
    let tasks: [TodoTask]
    let onToggle: (TodoTask) -> Void
    let onDelete: (TodoTask) -> Void
    let onEdit: (TodoTask) -> Void
    let theme: AppTheme
    
    var body: some View {
        if tasks.isEmpty {
            EmptyStateView()
        } else {
            List {
                ForEach(tasks) { task in
                    TaskRowView(
                        task: task,
                        onToggle: { onToggle(task) },
                        onEdit: { onEdit(task) },
                        theme: theme
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onDelete(task)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.white)
                        }
                        .tint(theme.accentColor)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
        }
    }
}

struct EmptyStateView: View {
    @Environment(\.selectedTheme) private var theme
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 50))
                .foregroundColor(theme.secondaryTextColor)
            
            Text("Žádné úkoly")
                .font(.title2)
                .foregroundColor(theme.textColor)
            
            Text("Přidej svůj první úkol!")
                .font(.caption)
                .foregroundColor(theme.secondaryTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Task Row View
struct TaskRowView: View {
    let task: TodoTask
    let onToggle: () -> Void
    let onEdit: () -> Void
    let theme: AppTheme
    
    var body: some View {
        HStack {
            // Zobrazit checkbox pouze pro aktivní úkoly
            if !task.isCompleted && !task.isExpired {
                CheckboxView(isCompleted: task.isCompleted, onToggle: onToggle)
            } else if task.isCompleted {
                // Pro splněné úkoly zobrazit světlejší zelenou ikonu (nelze odškrtnout)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.completedColor)
                    .font(.title2)
            } else {
                // Pro expirované nesplněné úkoly zobrazit ikonu "clock.badge.exclamationmark"
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(theme.expiredColor)
                    .font(.title2)
            }
            
            TaskContentView(task: task)
            
            // Zobrazit edit tlačítko pouze pro aktivní úkoly (ne splněné, ne expirované)
            if !task.isCompleted && !task.isExpired {
                EditButtonView(onEdit: onEdit)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(theme.taskRowBackground)
        .cornerRadius(8)
    }
}

struct CheckboxView: View {
    let isCompleted: Bool
    let onToggle: () -> Void
    @Environment(\.selectedTheme) private var theme
    
    var body: some View {
        Button(action: onToggle) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isCompleted ? theme.completedColor : theme.secondaryTextColor)
                .font(.title2)
                .scaleEffect(isCompleted ? 1.1 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(isCompleted ? "Odznačit jako nesplněný" : "Označit jako splněný")
    }
}

struct TaskContentView: View {
    let task: TodoTask
    @Environment(\.selectedTheme) private var theme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(task.title ?? "Bez názvu")
                    .font(.headline)
                    .foregroundColor(task.isCompleted ? theme.secondaryTextColor : theme.textColor)
                
                Spacer()
                
                TaskBadgeView(task: task)
            }
            
            if let description = task.taskDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryTextColor)
                    .lineLimit(2)
            }
            
            if let date = task.dueDate {
                TaskDateView(date: date, hasTime: task.hasTime)
            }
        }
    }
}

struct TaskBadgeView: View {
    let task: TodoTask
    @Environment(\.selectedTheme) private var theme
    
    var body: some View {
        Group {
            if task.isExpired && !task.isCompleted {
                BadgeView(text: "EXPIROVANÝ", color: theme.expiredColor)
                    .transition(.scale.combined(with: .opacity))
            } else if task.isCompleted {
                BadgeView(text: "SPLNĚNÝ", color: theme.completedColor)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

struct BadgeView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
}

struct TaskDateView: View {
    let date: Date
    let hasTime: Bool
    @Environment(\.selectedTheme) private var theme
    
    var body: some View {
        HStack {
            Label {
                Text(formatDateCzech(date))
            } icon: {
                Image(systemName: "calendar")
            }
            .font(.caption)
            .foregroundColor(theme.secondaryTextColor)
            
            if hasTime {
                Label {
                    Text("v \(formatTimeCzech(date))")
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption)
                .foregroundColor(theme.secondaryTextColor)
            }
        }
    }
    
    private func formatDateCzech(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTimeCzech(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EditButtonView: View {
    let onEdit: () -> Void
    @Environment(\.selectedTheme) private var theme
    
    var body: some View {
        Button(action: onEdit) {
            Image(systemName: "pencil")
                .foregroundColor(theme.accentColor)
                .padding(8)
                .background(theme.accentColor.opacity(0.1))
                .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews
#Preview {
    let context = PersistenceController.preview.container.viewContext
    
    // Add sample data for preview
    let sampleTask = TodoTask(context: context)
    sampleTask.id = UUID()
    sampleTask.title = "Test úkol"
    sampleTask.taskDescription = "Test popis"
    sampleTask.isCompleted = false
    sampleTask.createdAt = Date()
    sampleTask.dueDate = Date().addingTimeInterval(86400)
    
    try? context.save()
    
    return ContentView()
        .environment(\.managedObjectContext, context)
        .environment(\.todoRepository, DIContainer.preview.todoRepository)
        .environmentObject(DIContainer.preview)
}

#Preview("Simple Content View") {
    NavigationView {
        VStack(spacing: 0) {
            // Statistiky
            StatsView(statistics: TaskStatistics(
                totalCount: 3,
                completedCount: 1,
                activeCount: 1,
                expiredCount: 1
            ))
            
            // Filtry
            FilterBarView(selectedFilter: .constant(.all))
            
            // Prázdný stav
            EmptyStateView()
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .navigationTitle("Moje úkoly")
    }
}

#Preview("Stats View") {
    StatsView(statistics: TaskStatistics(
        totalCount: 10,
        completedCount: 3,
        activeCount: 5,
        expiredCount: 2
    ))
    .padding()
}

#Preview("Filter Bar") {
    FilterBarView(selectedFilter: .constant(.all))
}

#Preview("Empty State") {
    EmptyStateView()
}

#Preview("Task Row") {
    let context = PersistenceController.preview.container.viewContext
    let task = TodoTask(context: context)
    task.id = UUID()
    task.title = "Ukázkový úkol"
    task.taskDescription = "Toto je popis ukázkového úkolu"
    task.isCompleted = false
    task.createdAt = Date()
    task.dueDate = Date().addingTimeInterval(86400) // zítra
    
    return TaskRowView(
        task: task,
        onToggle: {},
        onEdit: {},
        theme: .default
    )
    .padding()
}
