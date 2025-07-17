//
//  Persistence.swift
//  ToDoApp
//
//  Created by Martin Hrbáček on 15.07.2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Přidáme ukázkové úkoly pro Preview
        let sampleTask1 = TodoTask(context: viewContext)
        sampleTask1.id = UUID()
        sampleTask1.title = "Nakoupit potraviny"
        sampleTask1.taskDescription = "Mléko, chléb, vejce"
        sampleTask1.isCompleted = false
        sampleTask1.createdAt = Date()
        sampleTask1.dueDate = Date().addingTimeInterval(86400) // zítra
        
        let sampleTask2 = TodoTask(context: viewContext)
        sampleTask2.id = UUID()
        sampleTask2.title = "Uklidit pokoj"
        sampleTask2.taskDescription = "Vysát, utřít prach"
        sampleTask2.isCompleted = true
        sampleTask2.createdAt = Date().addingTimeInterval(-86400) // včera
        sampleTask2.dueDate = Date()
        
        let sampleTask3 = TodoTask(context: viewContext)
        sampleTask3.id = UUID()
        sampleTask3.title = "Cvičit"
        sampleTask3.taskDescription = "30 minut kardio"
        sampleTask3.isCompleted = false
        sampleTask3.createdAt = Date()
        sampleTask3.dueDate = Date().addingTimeInterval(-3600) // před hodinou (expirované)
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ToDoApp")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
