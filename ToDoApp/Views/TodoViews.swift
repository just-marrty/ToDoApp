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
    @State private var uiUpdateTrigger = 0 // Force UI updates
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TodoTask.createdAt, ascending: false),
            NSSortDescriptor(keyPath: \TodoTask.dueDate, ascending: true)
        ]
    ) private var tasks: FetchedResults<TodoTask>
    
    // Listen to context changes to force UI updates
    @State private var contextChangeTrigger = 0
    
    init() {
        // Use DI container to create ViewModel
        self._viewModel = StateObject(wrappedValue: DIContainer.shared.makeContentViewModel())
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Statistiky
                StatsView(statistics: viewModel.statistics(from: Array(tasks)))
                
                // Filtry
                FilterBarView(selectedFilter: $viewModel.selectedFilter)
                
                // Seznam úkolů
                TaskListView(
                    tasks: viewModel.filteredTasks(from: Array(tasks)),
                    onToggle: { task in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.toggleTask(task)
                            // Force UI refresh
                            uiUpdateTrigger += 1
                        }
                    },
                    onDelete: viewModel.deleteTask,
                    onEdit: viewModel.editTask,
                    theme: viewModel.selectedTheme
                )
                .id("\(uiUpdateTrigger)-\(contextChangeTrigger)-\(tasks.map { $0.dueDate?.timeIntervalSince1970 ?? 0 }.reduce(0, +))") // Force refresh when tasks change or due dates change
                
                Spacer()
            }
            .background(viewModel.selectedTheme.backgroundColor)
            .navigationTitle("Moje úkoly")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ThemeToggleView(selectedTheme: $viewModel.selectedTheme)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showingAddTask = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(viewModel.selectedTheme.accentColor)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddTask) {
            AddTaskView(theme: viewModel.selectedTheme)
        }
        .sheet(isPresented: $viewModel.showingEditTask) {
            if let task = viewModel.taskToEdit {
                EditTaskView(task: task, theme: viewModel.selectedTheme)
            }
        }
        .preferredColorScheme(viewModel.selectedTheme.colorScheme)
        .environment(\.selectedTheme, viewModel.selectedTheme)
        .onReceive(NotificationCenter.default.publisher(for: .taskExpired)) { _ in
            // Force UI refresh when task expires
            withAnimation(.easeInOut(duration: 0.3)) {
                uiUpdateTrigger += 1
                contextChangeTrigger += 1
            }
        }
        .onAppear {
            // Refresh UI when app becomes active
            uiUpdateTrigger += 1
            
            // Kontrola expirovaných úkolů při otevření
            TaskExpirationManager.shared.checkAndMarkExpiredTasks()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Kontrola expirovaných úkolů při návratu z background
            TaskExpirationManager.shared.checkAndMarkExpiredTasks()
        }
        // .onReceive(viewContext.objectWillChange) { _ in
        //     // Force UI refresh when context changes
        //     contextChangeTrigger += 1
        // }
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
        .animation(.easeInOut(duration: 0.3), value: statistics.totalCount)
        .animation(.easeInOut(duration: 0.3), value: statistics.completedCount)
        .animation(.easeInOut(duration: 0.3), value: statistics.activeCount)
        .animation(.easeInOut(duration: 0.3), value: statistics.expiredCount)
        .id("\(statistics.totalCount)-\(statistics.completedCount)-\(statistics.activeCount)-\(statistics.expiredCount)") // Force refresh when statistics change
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
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: value)
            
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
            withAnimation(.easeInOut(duration: 0.3)) {
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
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onDelete(task)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.white)
                        }
                        .tint(theme.accentColor)
                    }
                    .id("\(task.objectID.uriRepresentation().absoluteString)-\(task.dueDate?.timeIntervalSince1970 ?? 0)-\(task.isCompleted)") // Force refresh on dueDate or completion
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .animation(.easeInOut(duration: 0.2), value: tasks.count)
            .id("\(tasks.count)-\(tasks.map { $0.dueDate?.timeIntervalSince1970 ?? 0 }.reduce(0, +))") // Force refresh when tasks count or due dates change
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
                    .animation(.easeInOut(duration: 0.3), value: task.isCompleted)
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
        .animation(.easeInOut(duration: 0.3), value: task.isCompleted)
        .id("\(task.objectID.uriRepresentation().absoluteString)-\(task.dueDate?.timeIntervalSince1970 ?? 0)-\(task.isCompleted)") // Force refresh on dueDate or completion
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
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isCompleted)
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
                    .animation(.easeInOut(duration: 0.3), value: task.isCompleted)
                
                Spacer()
                
                TaskBadgeView(task: task)
            }
            
            if let description = task.taskDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(theme.secondaryTextColor)
                    .lineLimit(2)
                    .animation(.easeInOut(duration: 0.3), value: task.isCompleted)
            }
            
            if let date = task.dueDate {
                TaskDateView(date: date, hasTime: task.hasTime)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: task.isCompleted)
        .id("\(task.objectID.uriRepresentation().absoluteString)-\(task.dueDate?.timeIntervalSince1970 ?? 0)-\(task.isCompleted)") // Force refresh on dueDate or completion
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
        .id("\(task.objectID.uriRepresentation().absoluteString)-\(task.dueDate?.timeIntervalSince1970 ?? 0)-\(task.isCompleted)-\(task.isExpired)") // Force refresh on dueDate, completion or expired
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
            .animation(.easeInOut(duration: 0.2), value: text)
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
        .id("\(date.timeIntervalSince1970)-\(hasTime)") // Force refresh when date or hasTime changes
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
