//
//  MainTabView.swift
//  ABudget
//
//  Created by Joshua King on 10/20/25.
//

import SwiftUI

struct MainTabView: View {

    // MARK: - Body

    var body: some View {
        TabView {
            BudgetView()
                .tabItem {
                    Label("Budget", systemImage: "calendar")
                }

            TransactionsView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet.rectangle")
                }

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.pie")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, CoreDataStack.preview.viewContext)
        .environmentObject(CoreDataStack.preview)
}
