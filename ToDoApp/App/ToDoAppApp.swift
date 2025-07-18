//
//  ToDoAppApp.swift
//  ToDoApp
//
//  Created by Martin Hrbáček on 16.07.2025.
//

import SwiftUI
import UserNotifications
import CoreData
import CloudKit

@main
struct ToDoAppApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var diContainer = DIContainer.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var expirationManager = TaskExpirationManager.shared
    @StateObject private var cloudKitStatusManager = CloudKitStatusManager.shared

    var body: some Scene {
        WindowGroup {
            LoadingView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.todoRepository, diContainer.todoRepository)
                .environmentObject(diContainer)
                .environmentObject(cloudKitStatusManager)
                .task {
                    // Požádat o povolení notifikací při spuštění
                    await requestPermission()
                }
                .onAppear {
                    // Nastavit delegate pro notifikace
                    UNUserNotificationCenter.current().delegate = NotificationHandler.shared
                    
                    // Kontrola expirovaných úkolů při spuštění
                    expirationManager.checkAndMarkExpiredTasks()
                    
                    // Kontrola CloudKit stavu
                    cloudKitStatusManager.checkCloudKitStatus()
                }
        }
    }
    
    private func requestPermission() async {
        let granted = await notificationManager.requestPermission()
        if granted {
            print("Notification permission granted")
        } else {
            print("Notification permission denied")
        }
    }
}

// MARK: - Notification Handler
class NotificationHandler: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationHandler()
    
    private override init() {
        super.init()
    }
    
    // Zpracování notifikace když je aplikace v popředí
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Zobrazit notifikaci i když je aplikace aktivní
        completionHandler([.banner, .sound, .badge])
    }
    
    // Zpracování notifikace když uživatel klikne na notifikaci
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        
        // Pokud je to notifikace o expiraci, označit úkol jako expirovaný
        if identifier.hasSuffix("_expired") {
            handleExpiredTaskNotification(identifier: identifier)
        }
        
        completionHandler()
    }
    
    private func handleExpiredTaskNotification(identifier: String) {
        // Extrahovat task ID z identifieru
        let taskIdString = identifier.replacingOccurrences(of: "_expired", with: "")
        guard let taskId = UUID(uuidString: taskIdString) else { return }
        
        // Najít úkol v Core Data a označit ho jako expirovaný
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest: NSFetchRequest<TodoTask> = TodoTask.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", taskId as CVarArg)
        
        do {
            let tasks = try context.fetch(fetchRequest)
            if let task = tasks.first {
                // Úkol už je expirovaný (dueDate < Date()), ale můžeme přidat nějaké označení
                // nebo logiku pro lepší zobrazení expirovaného stavu
                print("Task expired: \(task.title ?? "Unknown")")
                
                // Force refresh UI
                DispatchQueue.main.async {
                    // Trigger UI refresh
                    NotificationCenter.default.post(name: .taskExpired, object: task)
                }
            }
        } catch {
            print("Error handling expired task notification: \(error)")
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let taskExpired = Notification.Name("taskExpired")
}
