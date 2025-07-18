//
//  TodoViewModels.swift
//  ToDoApp
//
//  Created by Martin Hrbáček on 16.07.2025.
//

import SwiftUI
import CoreData
import Combine

// MARK: - Main Content ViewModel
class ContentViewModel: ObservableObject {
    @Published var selectedFilter: TaskFilter {
        didSet {
            // Uložit vybraný filtr do UserDefaults
            UserDefaults.standard.set(selectedFilter.rawValue, forKey: "selectedFilter")
            print("Filter changed to: \(selectedFilter.rawValue)")
        }
    }
    @Published var selectedTheme: AppTheme {
        didSet {
            // Uložit vybraný vzhled do UserDefaults
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
            print("Theme changed to: \(selectedTheme.name)")
        }
    }
    @Published var showingAddTask = false
    @Published var showingEditTask = false
    @Published var taskToEdit: TodoTask?
    
    private let repository: TodoRepositoryProtocol
    
    init(repository: TodoRepositoryProtocol) {
        self.repository = repository
        
        // Načíst uložený filtr z UserDefaults
        if let savedFilterRawValue = UserDefaults.standard.string(forKey: "selectedFilter"),
           let savedFilter = TaskFilter(rawValue: savedFilterRawValue) {
            self.selectedFilter = savedFilter
            print("Loaded saved filter: \(savedFilter.rawValue)")
        } else {
            self.selectedFilter = .all
            print("Using default filter: all")
        }
        
        // Načíst uložený vzhled z UserDefaults
        if let savedThemeRawValue = UserDefaults.standard.string(forKey: "selectedTheme"),
           let savedTheme = AppTheme(rawValue: savedThemeRawValue) {
            self.selectedTheme = savedTheme
            print("Loaded saved theme: \(savedTheme.name)")
        } else {
            self.selectedTheme = .default
            print("Using default theme")
        }
    }
    
    func filteredTasks(from tasks: [TodoTask]) -> [TodoTask] {
        repository.filterTasks(tasks, by: selectedFilter)
    }
    
    func statistics(from tasks: [TodoTask]) -> TaskStatistics {
        repository.calculateStatistics(for: tasks)
    }
    
    func toggleTask(_ task: TodoTask) {
        // Zabránit toggle splněných úkolů (nelze odškrtnout)
        if task.isCompleted {
            print("Cannot uncheck completed task: \(task.title ?? "Unknown")")
            return
        }
        
        // Zabránit toggle expirovaných nesplněných úkolů
        if task.isExpired && !task.isCompleted {
            print("Cannot toggle expired non-completed task: \(task.title ?? "Unknown")")
            return
        }
        
        Task {
            do {
                try await repository.toggleTask(task)
            } catch {
                print("Error toggling task: \(error)")
            }
        }
    }
    
    func deleteTask(_ task: TodoTask) {
        Task {
            do {
                try await repository.deleteTask(task)
            } catch {
                print("Error deleting task: \(error)")
            }
        }
    }
    
    func editTask(_ task: TodoTask) {
        // Zabránit editaci splněných úkolů
        if task.isCompleted {
            print("Cannot edit completed task: \(task.title ?? "Unknown")")
            return
        }
        
        taskToEdit = task
        showingEditTask = true
    }
}

// MARK: - Add Task ViewModel
class AddTaskViewModel: ObservableObject {
    @Published var taskData = NewTaskData()
    @Published var showingDateError = false
    
    private let repository: TodoRepositoryProtocol
    
    init(repository: TodoRepositoryProtocol) {
        self.repository = repository
    }
    
    func validateDateTime() {
        showingDateError = taskData.isInPast
    }
    
    func addTask() async -> Bool {
        guard taskData.isValid else { return false }
        
        do {
            try await repository.createTask(from: taskData)
            return true
        } catch {
            print("Error adding task: \(error)")
            return false
        }
    }
}

// MARK: - Edit Task ViewModel
class EditTaskViewModel: ObservableObject {
    @Published var title: String {
        didSet {
            print("Title changed in ViewModel: \(oldValue) -> \(title)")
        }
    }
    @Published var isCompleted: Bool {
        didSet {
            print("IsCompleted changed in ViewModel: \(oldValue) -> \(isCompleted)")
        }
    }
    @Published var selectedDate: Date {
        didSet {
            print("Selected date changed in ViewModel: \(oldValue) -> \(selectedDate)")
            validateDateTime()
        }
    }
    @Published var selectedTime: Date {
        didSet {
            print("Selected time changed in ViewModel: \(oldValue) -> \(selectedTime)")
            validateDateTime()
        }
    }
    @Published var hasTime: Bool {
        didSet {
            print("Has time changed in ViewModel: \(oldValue) -> \(hasTime)")
            validateDateTime()
        }
    }
    @Published var showingDateError = false
    
    let task: TodoTask // Změněno na let a public
    private let repository: TodoRepositoryProtocol
    
    init(task: TodoTask, repository: TodoRepositoryProtocol) {
        self.task = task
        self.repository = repository
        self.title = task.title ?? "Bez názvu"
        self.isCompleted = task.isCompleted
        
        // Inicializace data a času z existujícího úkolu
        if let dueDate = task.dueDate {
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: dueDate)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: dueDate)
            
            self.selectedDate = calendar.date(from: dateComponents) ?? Date()
            self.selectedTime = calendar.date(from: timeComponents) ?? Date()
            self.hasTime = timeComponents.hour != 0 || timeComponents.minute != 0
        } else {
            self.selectedDate = Date()
            self.selectedTime = Date()
            self.hasTime = false
        }
        
        print("EditTaskViewModel initialized for task: \(task.title ?? "Unknown")")
        print("   - Original due date: \(task.dueDate?.description ?? "nil")")
        print("   - Initial selected date: \(selectedDate.description)")
        print("   - Initial selected time: \(selectedTime.description)")
        print("   - Has time: \(hasTime)")
        
        // Validace při inicializaci
        validateDateTime()
    }
    
    var canSave: Bool {
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
    
    func validateDateTime() {
        showingDateError = isInPast
    }
    
    func saveChanges() async -> Bool {
        guard canSave else { return false }
        
        print("Saving changes for task: \(task.title ?? "Unknown")")
        print("   - Title: \(title)")
        print("   - Final DateTime: \(finalDateTime)")
        print("   - Is Completed: \(isCompleted)")
        
        do {
            try await repository.updateTask(task, title: title, isCompleted: isCompleted, dueDate: finalDateTime)
            print("Changes saved successfully")
            return true
        } catch {
            print("Error saving changes: \(error)")
            return false
        }
    }
}
