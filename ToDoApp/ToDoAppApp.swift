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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
