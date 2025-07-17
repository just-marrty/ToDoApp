//
//  TodoRepository.swift
//  ToDoApp
//
//  Created by Martin Hrbáček on 16.07.2025.
//

import CoreData
import Foundation

// MARK: - Repository Protocol
protocol TodoRepositoryProtocol {
    func createTask(from data: NewTaskData) throws
    func updateTask(_ task: TodoTask, title: String, isCompleted: Bool, dueDate: Date) throws
    func deleteTask(_ task: TodoTask) throws
    func toggleTask(_ task: TodoTask) throws
    func calculateStatistics(for tasks: [TodoTask]) -> TaskStatistics
    func filterTasks(_ tasks: [TodoTask], by filter: TaskFilter) -> [TodoTask]
}

// MARK: - Core Data Repository
class TodoRepository: ObservableObject, TodoRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    func createTask(from data: NewTaskData) throws {
        let newTask = TodoTask(context: viewContext)
        newTask.id = UUID()
        newTask.title = data.title.trimmingCharacters(in: .whitespaces)
        newTask.taskDescription = data.description.isEmpty ? nil : data.description
        newTask.isCompleted = false
        newTask.createdAt = Date()
        newTask.dueDate = data.finalDateTime
        
        try saveContext()
    }
    
    func updateTask(_ task: TodoTask, title: String, isCompleted: Bool, dueDate: Date) throws {
        // Zabránit úpravě splněných úkolů
        if task.isCompleted {
            print("Cannot update completed task: \(task.title ?? "Unknown")")
            return
        }
        
        print("Updating task: \(task.title ?? "Unknown")")
        print("   - Old due date: \(task.dueDate?.description ?? "nil")")
        print("   - New due date: \(dueDate.description)")
        
        task.title = title
        task.isCompleted = isCompleted
        task.dueDate = dueDate
        
        try saveContext()
        print("Task updated successfully")
    }
    
    func deleteTask(_ task: TodoTask) throws {
        viewContext.delete(task)
        try saveContext()
    }
    
    func toggleTask(_ task: TodoTask) throws {
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
        
        task.isCompleted.toggle()
        print("Toggling task: \(task.title ?? "Unknown") to \(task.isCompleted)")
        try saveContext()
        print("Task toggled successfully")
    }
    
    private func saveContext() throws {
        do {
            try viewContext.save()
            print("Context saved successfully")
        } catch {
            print("Error saving context: \(error)")
            throw error
        }
    }
    
    // MARK: - Task Statistics Calculator
    func calculateStatistics(for tasks: [TodoTask]) -> TaskStatistics {
        let completedCount = tasks.filter { $0.isCompleted }.count
        let activeCount = tasks.filter { !$0.isCompleted && !$0.isExpired }.count
        let expiredCount = tasks.filter { $0.isExpired && !$0.isCompleted }.count
        
        return TaskStatistics(
            totalCount: tasks.count,
            completedCount: completedCount,
            activeCount: activeCount,
            expiredCount: expiredCount
        )
    }
    
    func filterTasks(_ tasks: [TodoTask], by filter: TaskFilter) -> [TodoTask] {
        switch filter {
        case .all:
            return tasks
        case .active:
            return tasks.filter { !$0.isCompleted && !$0.isExpired }
        case .completed:
            return tasks.filter { $0.isCompleted }
        case .expired:
            return tasks.filter { $0.isExpired && !$0.isCompleted }
        }
    }
}
