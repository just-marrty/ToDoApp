///
//  NotificationManager.swift
//  ToDoApp
//
//  Created by Martin Hrbáček on 16.07.2025.
//

import Foundation
import UserNotifications
import SwiftUI

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    // MARK: - Request Permission
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    // MARK: - Schedule Notifications
    func scheduleTaskNotification(for task: TodoTask) {
        guard let dueDate = task.dueDate,
              let title = task.title,
              !task.isCompleted else { return }
        
        // Zrušit existující notifikace pro tento úkol
        cancelTaskNotifications(for: task)
        
        // Naplánovat notifikace v různých časech
        scheduleNotification(
            for: task,
            title: "Připomenutí úkolu",
            body: "Úkol '\(title)' má deadline za 15 minut",
            date: dueDate.addingTimeInterval(-15 * 60), // 15 minut před
            identifier: "\(task.id?.uuidString ?? "")_15min"
        )
        
        scheduleNotification(
            for: task,
            title: "Připomenutí úkolu",
            body: "Úkol '\(title)' má deadline za 1 hodinu",
            date: dueDate.addingTimeInterval(-60 * 60), // 1 hodina před
            identifier: "\(task.id?.uuidString ?? "")_1hour"
        )
        
        scheduleNotification(
            for: task,
            title: "Připomenutí úkolu",
            body: "Úkol '\(title)' má deadline za 6 hodin",
            date: dueDate.addingTimeInterval(-6 * 60 * 60), // 6 hodin před
            identifier: "\(task.id?.uuidString ?? "")_6hours"
        )
                
        scheduleNotification(
            for: task,
            title: "Připomenutí úkolu",
            body: "Úkol '\(title)' má deadline za 12 hodin",
            date: dueDate.addingTimeInterval(-12 * 60 * 60), // 12 hodin před
            identifier: "\(task.id?.uuidString ?? "")_12hours"
        )
        
        // Notifikace v den deadlinu ráno (8:00)
        if let morningDate = getMorningDate(for: dueDate) {
            scheduleNotification(
                for: task,
                title: "Deadline dnes",
                body: "Úkol '\(title)' má deadline dnes",
                date: morningDate,
                identifier: "\(task.id?.uuidString ?? "")_morning"
            )
        }
    }
    
    // MARK: - Cancel Notifications
    func cancelTaskNotifications(for task: TodoTask) {
        guard let taskId = task.id?.uuidString else { return }
        
        let identifiers = [
            "\(taskId)_15min",
            "\(taskId)_1hour",
            "\(taskId)_morning"
        ]
        
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // MARK: - Private Methods
    private func scheduleNotification(
        for task: TodoTask,
        title: String,
        body: String,
        date: Date,
        identifier: String
    ) {
        // Neplánovat notifikace do minulosti
        guard date > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            ),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    private func getMorningDate(for date: Date) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 8
        components.minute = 0
        return calendar.date(from: components)
    }
    
    // MARK: - Check Permission Status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
}
