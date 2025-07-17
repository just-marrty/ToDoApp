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
        
        do {
            try repository.toggleTask(task)
        } catch {
            print("Error toggling task: \(error)")
        }
    }
    
    func deleteTask(_ task: TodoTask) {
        do {
            try repository.deleteTask(task)
        } catch {
            print("Error deleting task: \(error)")
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
    
    func addTask() -> Bool {
        guard taskData.isValid else { return false }
        
        do {
            try repository.createTask(from: taskData)
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
    @Published var dueDate: Date {
        didSet {
            print("Due date changed in ViewModel: \(oldValue) -> \(dueDate)")
        }
    }
    
    let task: TodoTask // Změněno na let a public
    private let repository: TodoRepositoryProtocol
    
    init(task: TodoTask, repository: TodoRepositoryProtocol) {
        self.task = task
        self.repository = repository
        self.title = task.title ?? "Bez názvu"
        self.isCompleted = task.isCompleted
        self.dueDate = task.dueDate ?? Date()
        
        print("EditTaskViewModel initialized for task: \(task.title ?? "Unknown")")
        print("   - Original due date: \(task.dueDate?.description ?? "nil")")
        print("   - Initial due date: \(dueDate.description)")
    }
    
    var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var dateRange: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: Date())
        let futureDate = Calendar.current.date(byAdding: .year, value: 10, to: today) ?? Date()
        return today...futureDate
    }
    
    func saveChanges() -> Bool {
        guard canSave else { return false }
        
        print("Saving changes for task: \(task.title ?? "Unknown")")
        print("   - Title: \(title)")
        print("   - Due Date: \(dueDate)")
        print("   - Is Completed: \(isCompleted)")
        
        do {
            try repository.updateTask(task, title: title, isCompleted: isCompleted, dueDate: dueDate)
            print("Changes saved successfully")
            return true
        } catch {
            print("Error saving changes: \(error)")
            return false
        }
    }
}
