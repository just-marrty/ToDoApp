//
//  TodoModals.swift
//  ToDoApp
//
//  Created by Martin Hrbáček on 16.07.2025.
//

import SwiftUI
import CoreData

// MARK: - Add Task View
struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddTaskViewModel
    
    let theme: AppTheme
    
    init(theme: AppTheme) {
        self.theme = theme
        // Use DI container to create ViewModel
        self._viewModel = StateObject(wrappedValue: DIContainer.shared.makeAddTaskViewModel())
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    BasicInfoSection(
                        title: $viewModel.taskData.title,
                        description: $viewModel.taskData.description,
                        theme: theme
                    )
                    
                    DateTimeSection(
                        taskData: $viewModel.taskData,
                        showingDateError: viewModel.showingDateError,
                        onDateChange: viewModel.validateDateTime,
                        theme: theme
                    )
                }
            }
            .background(theme.backgroundColor)
            .navigationTitle("Nový úkol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Zrušit") { dismiss() }
                        .foregroundColor(theme.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Přidat") {
                        if viewModel.addTask() {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.taskData.isValid)
                    .foregroundColor(theme.accentColor)
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
    }
}

// MARK: - Edit Task View
struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditTaskViewModel
    
    let theme: AppTheme
    
    init(task: TodoTask, theme: AppTheme) {
        self.theme = theme
        // Use DI container to create ViewModel
        self._viewModel = StateObject(wrappedValue: DIContainer.shared.makeEditTaskViewModel(task: task))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Úkol sekce
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Úkol")
                                .font(.headline)
                                .foregroundColor(theme.textColor)
                                .padding(.horizontal)
                                .padding(.top, 16)
                                .padding(.bottom, 4)
                                .underline(true, color: theme.secondaryTextColor.opacity(0.5))
                        }
                        
                        VStack(spacing: 0) {
                            TextField("Název úkolu", text: $viewModel.title)
                                .disabled(viewModel.task.isCompleted)
                                .foregroundColor(theme.textColor)
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(theme.backgroundColor)
                            
                            Divider()
                                .background(theme.secondaryTextColor.opacity(0.3))
                            
                            HStack {
                                Text("Splněno")
                                    .foregroundColor(theme.textColor)
                                Spacer()
                                Toggle("", isOn: $viewModel.isCompleted)
                                    .disabled(viewModel.task.isCompleted)
                                    .tint(theme.accentColor)
                                    .labelsHidden()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(theme.backgroundColor)
                            
                            Divider()
                                .background(theme.secondaryTextColor.opacity(0.3))
                        }
                    }
                    
                    // Termín sekce
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Termín")
                                .font(.headline)
                                .foregroundColor(theme.textColor)
                                .padding(.horizontal)
                                .padding(.top, 16)
                                .padding(.bottom, 4)
                                .underline(true, color: theme.secondaryTextColor.opacity(0.5))
                        }
                        
                        VStack(spacing: 0) {
                            HStack {
                                Text("Datum")
                                    .foregroundColor(theme.textColor)
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: $viewModel.selectedDate,
                                    in: viewModel.dateRange,
                                    displayedComponents: .date
                                )
                                .disabled(viewModel.task.isCompleted)
                                .onChange(of: viewModel.selectedDate) { _, _ in
                                    print("🔄 Selected date changed in EditTaskView")
                                }
                                .labelsHidden()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(theme.backgroundColor)
                            
                            Divider()
                                .background(theme.secondaryTextColor.opacity(0.3))
                            
                            HStack {
                                Text("Přidat čas")
                                    .foregroundColor(theme.textColor)
                                Spacer()
                                Toggle("", isOn: $viewModel.hasTime)
                                    .onChange(of: viewModel.hasTime) { _, newValue in
                                        if newValue {
                                            viewModel.selectedTime = Date()
                                        }
                                        print("🔄 Has time changed in EditTaskView: \(newValue)")
                                    }
                                    .disabled(viewModel.task.isCompleted)
                                    .tint(theme.accentColor)
                                    .labelsHidden()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(theme.backgroundColor)
                            
                            Divider()
                                .background(theme.secondaryTextColor.opacity(0.3))
                            
                            if viewModel.hasTime {
                                HStack {
                                    Text("Čas")
                                        .foregroundColor(theme.textColor)
                                    Spacer()
                                    DatePicker(
                                        "",
                                        selection: $viewModel.selectedTime,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .disabled(viewModel.task.isCompleted)
                                    .onChange(of: viewModel.selectedTime) { _, _ in
                                        print("🔄 Selected time changed in EditTaskView")
                                    }
                                    .labelsHidden()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(theme.backgroundColor)
                                
                                Divider()
                                    .background(theme.secondaryTextColor.opacity(0.3))
                            }
                        }
                        
                        if viewModel.showingDateError {
                            Text("Nelze nastavit termín v minulosti")
                                .foregroundColor(theme.expiredColor)
                                .font(.caption)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }
                    }
                    
                    // Informace sekce
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Informace")
                                .font(.headline)
                                .foregroundColor(theme.textColor)
                                .padding(.horizontal)
                                .padding(.top, 16)
                                .padding(.bottom, 4)
                                .underline(true, color: theme.secondaryTextColor.opacity(0.5))
                        }
                        
                        VStack(spacing: 0) {
                            if let createdAt = viewModel.task.createdAt {
                                HStack {
                                    Text("Vytvořeno")
                                        .foregroundColor(theme.textColor)
                                    Spacer()
                                    Text(formatDateTimeCzech(createdAt))
                                        .foregroundColor(theme.secondaryTextColor)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(theme.backgroundColor)
                                
                                Divider()
                                    .background(theme.secondaryTextColor.opacity(0.3))
                            }
                            
                            if let dueDate = viewModel.task.dueDate {
                                HStack {
                                    Text("Původní termín")
                                        .foregroundColor(theme.textColor)
                                    Spacer()
                                    Text(formatDateTimeCzech(dueDate))
                                        .foregroundColor(theme.secondaryTextColor)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(theme.backgroundColor)
                                
                                Divider()
                                    .background(theme.secondaryTextColor.opacity(0.3))
                            }
                        }
                    }
                    
                    // Info o splněných úkolech
                    if viewModel.task.isCompleted {
                        VStack(alignment: .leading, spacing: 0) {
                            VStack(spacing: 0) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(theme.accentColor)
                                    Text("Splněné úkoly nelze upravovat")
                                        .foregroundColor(theme.secondaryTextColor)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(theme.backgroundColor)
                                
                                Divider()
                                    .background(theme.secondaryTextColor.opacity(0.3))
                            }
                        }
                    }
                }
            }
            .background(theme.backgroundColor)
            .navigationTitle("Upravit úkol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Zrušit") { dismiss() }
                        .foregroundColor(theme.accentColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Uložit") {
                        if viewModel.saveChanges() {
                            // Force UI refresh after saving
                            DispatchQueue.main.async {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.task.isCompleted)
                    .foregroundColor(theme.accentColor)
                }
            }
        }
        .preferredColorScheme(theme.colorScheme)
    }
    
    private func formatDateTimeCzech(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Form Sections
struct BasicInfoSection: View {
    @Binding var title: String
    @Binding var description: String
    let theme: AppTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Základní informace")
                    .font(.headline)
                    .foregroundColor(theme.textColor)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                    .underline(true, color: theme.secondaryTextColor.opacity(0.5))
            }
            
            VStack(spacing: 0) {
                TextField("Název úkolu", text: $title)
                    .foregroundColor(theme.textColor)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(theme.backgroundColor)
                
                Divider()
                    .background(theme.secondaryTextColor.opacity(0.3))
                
                TextField("Popis úkolu", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                    .foregroundColor(theme.textColor)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(theme.backgroundColor)
                
                Divider()
                    .background(theme.secondaryTextColor.opacity(0.3))
            }
        }
    }
}

struct DateTimeSection: View {
    @Binding var taskData: NewTaskData
    let showingDateError: Bool
    let onDateChange: () -> Void
    let theme: AppTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Termín")
                    .font(.headline)
                    .foregroundColor(theme.textColor)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                    .underline(true, color: theme.secondaryTextColor.opacity(0.5))
            }
            
            VStack(spacing: 0) {
                HStack {
                    Text("Datum")
                        .foregroundColor(theme.textColor)
                    Spacer()
                    DatePicker(
                        "",
                        selection: $taskData.selectedDate,
                        in: taskData.dateRange,
                        displayedComponents: .date
                    )
                    .onChange(of: taskData.selectedDate) { _, _ in
                        onDateChange()
                    }
                    .labelsHidden()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(theme.backgroundColor)
                
                Divider()
                    .background(theme.secondaryTextColor.opacity(0.3))
                
                HStack {
                    Text("Přidat čas")
                        .foregroundColor(theme.textColor)
                    Spacer()
                    Toggle("", isOn: $taskData.hasTime)
                        .onChange(of: taskData.hasTime) { _, newValue in
                            if newValue {
                                taskData.selectedTime = Date()
                            }
                            onDateChange()
                        }
                        .tint(theme.accentColor)
                        .labelsHidden()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(theme.backgroundColor)
                
                Divider()
                    .background(theme.secondaryTextColor.opacity(0.3))
                
                if taskData.hasTime {
                    HStack {
                        Text("Čas")
                            .foregroundColor(theme.textColor)
                        Spacer()
                        DatePicker(
                            "",
                            selection: $taskData.selectedTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: taskData.selectedTime) { _, _ in
                            onDateChange()
                        }
                        .labelsHidden()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(theme.backgroundColor)
                    
                    Divider()
                        .background(theme.secondaryTextColor.opacity(0.3))
                }
            }
            
            if showingDateError {
                Text("Nelze vytvořit úkol v minulosti")
                    .foregroundColor(theme.expiredColor)
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
        }
    }
}

struct TaskInfoSection: View {
    let task: TodoTask
    
    var body: some View {
        Section("Informace") {
            if let createdAt = task.createdAt {
                InfoRow(label: "Vytvořeno", value: formatDateCzech(createdAt))
            }
            
            if let dueDate = task.dueDate {
                InfoRow(label: "Původní termín", value: formatDateCzech(dueDate))
            }
        }
    }
    
    private func formatDateCzech(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    @Environment(\.selectedTheme) private var theme
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(theme.textColor)
            Spacer()
            Text(value)
                .foregroundColor(theme.secondaryTextColor)
        }
    }
}
