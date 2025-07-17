//
//  ToDoAppApp.swift
//  ToDoApp
//
//  Created by Martin Hrbáček on 15.07.2025.
//

import SwiftUI

@main
struct ToDoAppApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var diContainer = DIContainer.shared

    var body: some Scene {
        WindowGroup {
            LoadingView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(\.todoRepository, diContainer.todoRepository)
                .environmentObject(diContainer)
        }
    }
}
