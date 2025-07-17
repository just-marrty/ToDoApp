//
//  ToDoAppApp.swift
//  ToDoApp
//
//  Created by Martin Hrbáček on 15.07.2025.
//

import SwiftUI
import UserNotifications

@main
struct ToDoAppApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var diContainer = DIContainer.shared
    @StateObject private var notificationManager = NotificationManager.shared

    var body: some Scene {
        WindowGroup {
            LoadingView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.todoRepository, diContainer.todoRepository)
                .environmentObject(diContainer)
                .task {
                    // Požádat o povolení notifikací při spuštění
                    await requestNotificationPermission()
                }
        }
    }
    
    private func requestNotificationPermission() async {
        let granted = await notificationManager.requestPermission()
        if granted {
            print("Notification permission granted")
        } else {
            print("Notification permission denied")
        }
    }
}
