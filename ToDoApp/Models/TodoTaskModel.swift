//
//  TodoTaskModel.swift
//  ToDoApp
//
//  Created by Martin Hrbáček on 16.07.2025.
//

import Foundation
import SwiftUI
import CoreData

// MARK: - Dependency Injection Container
class DIContainer: ObservableObject {
    static let shared = DIContainer()
    
    private let persistenceController: PersistenceController
    
    private init() {
        self.persistenceController = PersistenceController.shared
    }
    
    // MARK: - Repository
    lazy var todoRepository: TodoRepositoryProtocol = {
        TodoRepository(viewContext: persistenceController.container.viewContext)
    }()
    
    // MARK: - ViewModels
    func makeContentViewModel() -> ContentViewModel {
        ContentViewModel(repository: todoRepository)
    }
    
    func makeAddTaskViewModel() -> AddTaskViewModel {
        AddTaskViewModel(repository: todoRepository)
    }
    
    func makeEditTaskViewModel(task: TodoTask) -> EditTaskViewModel {
        EditTaskViewModel(task: task, repository: todoRepository)
    }
    
    // MARK: - CloudKit Status Manager
    lazy var cloudKitStatusManager: CloudKitStatusManager = {
        CloudKitStatusManager.shared
    }()
    
    // MARK: - Core Data Context
    var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
}

// MARK: - Preview DI Container
extension DIContainer {
    static let preview: DIContainer = {
        let container = DIContainer()
        // Use preview context for testing
        return container
    }()
}

// MARK: - Environment Key
struct TodoRepositoryKey: EnvironmentKey {
    static let defaultValue: TodoRepositoryProtocol = DIContainer.shared.todoRepository
}

extension EnvironmentValues {
    var todoRepository: TodoRepositoryProtocol {
        get { self[TodoRepositoryKey.self] }
        set { self[TodoRepositoryKey.self] = newValue }
    }
    
    var selectedTheme: AppTheme {
        get { self[SelectedThemeKey.self] }
        set { self[SelectedThemeKey.self] = newValue }
    }
}

struct SelectedThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .default
}

// MARK: - Task Filter Enum
enum TaskFilter: String, CaseIterable {
    case all = "Vše"
    case active = "Aktivní"
    case completed = "Splněné"
    case expired = "Expirované"
}

// MARK: - App Theme Enum
enum AppTheme: String, CaseIterable {
    case `default` = "default"
    case dark = "dark"
    
    var name: String {
        switch self {
        case .default: return "Světlý"
        case .dark: return "Tmavý"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .default: return Color(red: 0.94, green: 0.96, blue: 0.98) // Světle modré pozadí
        case .dark: return Color(red: 0.10, green: 0.12, blue: 0.16) // Tmavě modré pozadí
        }
    }

    var taskRowBackground: Color {
        switch self {
        case .default: return Color(red: 0.88, green: 0.92, blue: 0.96) // Světle modro-šedé
        case .dark: return Color(red: 0.16, green: 0.18, blue: 0.22) // Tmavší modro-šedá
        }
    }

    var accentColor: Color {
        switch self {
        case .default: return Color(red: 0.35, green: 0.50, blue: 0.85) // Jasně modrá akcent
        case .dark: return Color(red: 0.45, green: 0.60, blue: 0.90) // Světlejší modrá
        }
    }

    var textColor: Color {
        switch self {
        case .default: return Color(red: 0.20, green: 0.25, blue: 0.30) // Tmavý modro-šedý text
        case .dark: return Color(red: 0.90, green: 0.92, blue: 0.95) // Světlý text s nádechem modré
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .default: return Color(red: 0.40, green: 0.45, blue: 0.50) // Modro-šedý text
        case .dark: return Color(red: 0.70, green: 0.75, blue: 0.80) // Světle modro-šedý text
        }
    }

    var expiredColor: Color {
        switch self {
        case .default: return Color(red: 0.85, green: 0.35, blue: 0.45) // Červeno-růžová pro expirované
        case .dark: return Color(red: 0.90, green: 0.45, blue: 0.55) // Světlejší červeno-růžová
        }
    }

    var completedColor: Color {
        switch self {
        case .default: return Color(red: 0.30, green: 0.75, blue: 0.55) // Zeleno-tyrkysová pro splněné
        case .dark: return Color(red: 0.40, green: 0.80, blue: 0.65) // Světlejší zeleno-tyrkysová
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        default: return .light
        }
    }
}

// MARK: - Task Statistics
struct TaskStatistics {
    let totalCount: Int
    let completedCount: Int
    let activeCount: Int
    let expiredCount: Int
    
    static let empty = TaskStatistics(
        totalCount: 0,
        completedCount: 0,
        activeCount: 0,
        expiredCount: 0
    )
}

// MARK: - Task Extensions
extension TodoTask {
    var isExpired: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date()
    }
    
    var hasTime: Bool {
        guard let date = dueDate else { return false }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return components.hour != 0 || components.minute != 0
    }
    
    // Automatické označení jako expirované při přístupu
    var isExpiredWithAutoMark: Bool {
        let expired = isExpired
        if expired && !isCompleted {
            // Automaticky označit jako expirované (můžeme přidat nějaké pole pro tracking)
            print("Task auto-marked as expired: \(title ?? "Unknown")")
        }
        return expired
    }
}

// MARK: - Task Expiration Manager
class TaskExpirationManager: ObservableObject {
    static let shared = TaskExpirationManager()
    
    private init() {}
    
    // Kontrola a označení expirovaných úkolů
    func checkAndMarkExpiredTasks() {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<TodoTask> = TodoTask.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "dueDate < %@ AND isCompleted == NO", Date() as CVarArg)
        
        do {
            let expiredTasks = try context.fetch(fetchRequest)
            if !expiredTasks.isEmpty {
                print("Found \(expiredTasks.count) expired tasks")
                
                // Force UI refresh
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .taskExpired, object: nil)
                }
            }
        } catch {
            print("Error checking expired tasks: \(error)")
        }
    }
}

// MARK: - New Task Data
struct NewTaskData {
    var title: String = ""
    var description: String = ""
    var selectedDate: Date = Date()
    var selectedTime: Date = Date()
    var hasTime: Bool = false
    
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !isInPast
    }
    
    var isInPast: Bool {
        finalDateTime < Date()
    }
    
    var finalDateTime: Date {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        
        if hasTime {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
        } else {
            dateComponents.hour = 23
            dateComponents.minute = 59
        }
        
        return calendar.date(from: dateComponents) ?? selectedDate
    }
    
    var dateRange: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: Date())
        let futureDate = Calendar.current.date(byAdding: .year, value: 10, to: today) ?? Date()
        return today...futureDate
    }
}
