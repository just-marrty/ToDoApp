//
//  TodoRepository.swift
//  ToDoApp
//
//  Created by Martin Hrbáček on 16.07.2025.
//

import CoreData
import Foundation
import CloudKit

// MARK: - Repository Protocol
protocol TodoRepositoryProtocol {
    func createTask(from data: NewTaskData) async throws
    func updateTask(_ task: TodoTask, title: String, isCompleted: Bool, dueDate: Date) async throws
    func deleteTask(_ task: TodoTask) async throws
    func toggleTask(_ task: TodoTask) async throws
    func calculateStatistics(for tasks: [TodoTask]) -> TaskStatistics
    func filterTasks(_ tasks: [TodoTask], by filter: TaskFilter) -> [TodoTask]
    func syncWithCloudKit() async throws
}

// MARK: - Core Data Repository
class TodoRepository: ObservableObject, TodoRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let notificationManager = NotificationManager.shared
    private let cloudKitStatusManager = CloudKitStatusManager.shared
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
    }
    
    func createTask(from data: NewTaskData) async throws {
        let newTask = TodoTask(context: viewContext)
        newTask.id = UUID()
        newTask.title = data.title.trimmingCharacters(in: .whitespaces)
        newTask.taskDescription = data.description.isEmpty ? nil : data.description
        newTask.isCompleted = false
        newTask.createdAt = Date()
        newTask.dueDate = data.finalDateTime
        
        try saveContext()
        
        // Naplánovat notifikace pro nový úkol
        notificationManager.scheduleTaskNotification(for: newTask)
        
        // Trigger CloudKit sync
        await triggerCloudKitSync()
    }
    
    func updateTask(_ task: TodoTask, title: String, isCompleted: Bool, dueDate: Date) async throws {
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
        
        // Force refresh the task object
        viewContext.refresh(task, mergeChanges: true)
        
        // Post notification to refresh UI
        await MainActor.run {
            NotificationCenter.default.post(name: .taskUpdated, object: task)
        }
        
        // Aktualizovat notifikace
        if isCompleted {
            notificationManager.cancelTaskNotifications(for: task)
        } else {
            notificationManager.scheduleTaskNotification(for: task)
        }
        
        // Trigger CloudKit sync
        await triggerCloudKitSync()
        
        print("Task updated successfully")
    }
    
    func toggleTask(_ task: TodoTask) async throws {
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
        
        // Aktualizovat notifikace
        if task.isCompleted {
            notificationManager.cancelTaskNotifications(for: task)
        } else {
            notificationManager.scheduleTaskNotification(for: task)
        }
        
        try saveContext()
        
        // Trigger CloudKit sync
        await triggerCloudKitSync()
        
        print("Task toggled successfully")
    }
    
    func deleteTask(_ task: TodoTask) async throws {
        // Zrušit notifikace před smazáním
        notificationManager.cancelTaskNotifications(for: task)
        
        viewContext.delete(task)
        try saveContext()
        
        // Trigger CloudKit sync
        await triggerCloudKitSync()
    }
    
    private func saveContext() throws {
        do {
            try viewContext.save()
            print("Context saved successfully")
        } catch {
            print("Error saving context: \(error)")
            
            // CloudKit specific error handling
            if let cloudKitError = error as? CKError {
                handleCloudKitError(cloudKitError)
            }
            
            throw error
        }
    }
    
    // MARK: - CloudKit Error Handling
    private func handleCloudKitError(_ error: CKError) {
        switch error.code {
        case .networkUnavailable:
            print("CloudKit: Network unavailable - data will sync when connection is restored")
        case .networkFailure:
            print("CloudKit: Network failure - retrying...")
        case .quotaExceeded:
            print("CloudKit: Quota exceeded")
        case .userDeletedZone:
            print("CloudKit: User deleted zone - recreating...")
        case .changeTokenExpired:
            print("CloudKit: Change token expired - refreshing...")
        default:
            print("CloudKit error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - CloudKit Sync
    private func triggerCloudKitSync() async {
        // Trigger UI update pro sync status
        await MainActor.run {
            cloudKitStatusManager.requestSync()
        }
    }
    
    func syncWithCloudKit() async throws {
        // Force CloudKit sync
        await MainActor.run {
            cloudKitStatusManager.syncStatus = .syncing
        }
        
        // Simulace CloudKit sync (v reálné aplikaci by zde byla skutečná CloudKit operace)
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 sekunda
        
        await MainActor.run {
            cloudKitStatusManager.syncStatus = .synced
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
