//
//  ABudgetApp.swift
//  ABudget
//
//  Created by Joshua King on 10/20/25.
//

import SwiftUI

@main
struct ABudgetApp: App {

    // MARK: - Properties

    private let coreDataStack = CoreDataStack.shared

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(\.managedObjectContext, coreDataStack.viewContext)
        }
    }
}
