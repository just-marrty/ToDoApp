//
//  LoadingView.swift
//  ToDoApp
//
//  Created by Martin Hrbáček on 16.07.2025.
//

import SwiftUI
import CoreData

struct LoadingView: View {
    @State private var isActive = false
    @State private var opacity = 0.0
    @State private var scale = 0.8
    @State private var selectedTheme: AppTheme = .default
    
    init() {
        // Načíst uložené téma z UserDefaults
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            _selectedTheme = State(initialValue: theme)
        }
    }
    
    var body: some View {
        ZStack {
            // Pozadí podle tématu
            selectedTheme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Logo nad nadpis
                VStack(spacing: 12) {
                    Image("todo-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .scaleEffect(scale)
                        .opacity(opacity)
                    
                    Text("Moje úkoly")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .opacity(opacity)
                }
                
                Spacer()
                
                // Spodní text s odkazem v jednom řádku
                HStack(spacing: 4) {
                    Text("Moje úkoly verze 1.0 by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(opacity)
                    
                    Link("just_marrty", destination: URL(string: "https://www.my-games.eu/")!)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTheme.accentColor) // Tmavě oranžová podle tématu
                        .opacity(opacity)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                opacity = 1.0
                scale = 1.0
            }
            
            // Po 3 sekundách přejít na hlavní aplikaci
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isActive = true
                }
            }
        }
        .preferredColorScheme(selectedTheme.colorScheme)
        .fullScreenCover(isPresented: $isActive) {
            ContentView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
                .environment(\.todoRepository, DIContainer.shared.todoRepository)
                .environmentObject(DIContainer.shared)
        }
    }
}

#Preview {
    LoadingView()
}
