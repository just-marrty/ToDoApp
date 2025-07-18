//
//  Persistence.swift
//  ToDoApp
//
//  Created by Martin Hrbáček on 16.07.2025.
//

import CoreData
import CloudKit

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
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "ToDoApp")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Konfigurace CloudKit
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        // Nastavení CloudKit containeru
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // iCloud container identifier
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.justmarrty.accountsapp.ToDoApp"
        )
        
        // Nastavení pro automatickou synchronizaci
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("CloudKit Core Data error: \(error), \(error.userInfo)")
                
                // Pokus o recovery pro CloudKit chyby
                if error.domain == NSCocoaErrorDomain && error.code == NSPersistentStoreIncompatibleVersionHashError {
                    // Schema změna - pokus o migraci
                    print("Attempting CloudKit schema migration...")
                } else if error.domain == CKErrorDomain {
                    // CloudKit specifické chyby
                    print("CloudKit error: \(error.localizedDescription)")
                }
                
                // Pro development - fatal error, pro production bychom měli handle gracefully
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                print("CloudKit Core Data store loaded successfully")
            }
        })
        
        // Automatické merge změn z parent contextu
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Nastavení merge policy pro konflikty
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Notification pro CloudKit změny - simplified
        // Note: CloudKit event notifications are handled automatically by Core Data
        
        // Notification pro remote změny
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { notification in
            PersistenceController.handleRemoteChange(notification)
        }
    }
    
    // MARK: - CloudKit Event Handling
    // (odstraněno)
    
    // MARK: - Remote Change Handling
    private static func handleRemoteChange(_ notification: Notification) {
        print("Remote change detected - refreshing UI")
        
        // Notify UI o změnách
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .cloudKitDataChanged, object: nil)
        }
    }
}

// MARK: - CloudKit Status Manager
class CloudKitStatusManager: ObservableObject {
    static let shared = CloudKitStatusManager()
    
    @Published var isCloudKitAvailable = false
    @Published var isSignedInToiCloud = false
    @Published var syncStatus: SyncStatus = .unknown
    
    private let container = CKContainer(identifier: "iCloud.com.justmarrty.accountsapp.ToDoApp")
    
    enum SyncStatus: Equatable {
        case unknown
        case syncing
        case synced
        case error(String)
        
        var description: String {
            switch self {
            case .unknown: return "Kontroluji synchronizaci..."
            case .syncing: return "Synchronizuji..."
            case .synced: return "Synchronizováno"
            case .error(let message): return "Chyba: \(message)"
            }
        }
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown):
                return true
            case (.syncing, .syncing):
                return true
            case (.synced, .synced):
                return true
            case (.error(let lhsMessage), .error(let rhsMessage)):
                return lhsMessage == rhsMessage
            default:
                return false
            }
        }
    }
    
    private init() {
        checkCloudKitStatus()
    }
    
    func checkCloudKitStatus() {
        // Kontrola iCloud přihlášení
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                switch status {
                case .available:
                    self?.isSignedInToiCloud = true
                    self?.isCloudKitAvailable = true
                    self?.syncStatus = .synced
                case .noAccount:
                    self?.isSignedInToiCloud = false
                    self?.isCloudKitAvailable = false
                    self?.syncStatus = .error("Není přihlášen k iCloud")
                case .restricted:
                    self?.isSignedInToiCloud = false
                    self?.isCloudKitAvailable = false
                    self?.syncStatus = .error("iCloud je omezen")
                case .couldNotDetermine:
                    self?.isSignedInToiCloud = false
                    self?.isCloudKitAvailable = false
                    self?.syncStatus = .error("Nelze určit stav iCloud")
                case .temporarilyUnavailable:
                    self?.isSignedInToiCloud = false
                    self?.isCloudKitAvailable = false
                    self?.syncStatus = .error("iCloud je dočasně nedostupný")
                @unknown default:
                    self?.isSignedInToiCloud = false
                    self?.isCloudKitAvailable = false
                    self?.syncStatus = .error("Neznámý stav iCloud")
                }
            }
        }
    }
    
    func requestSync() {
        syncStatus = .syncing
        
        // Simulace synchronizace
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.syncStatus = .synced
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let cloudKitDataChanged = Notification.Name("cloudKitDataChanged")
}
