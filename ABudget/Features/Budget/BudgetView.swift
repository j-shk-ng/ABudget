//
//  BudgetView.swift
//  ABudget
//
//  Created by Joshua King on 10/20/25.
//

import SwiftUI

/// Main Budget tab - delegates to BudgetListView
struct BudgetView: View {

    // MARK: - Body

    var body: some View {
        BudgetListView()
    }
}

// MARK: - Preview

#Preview {
    BudgetView()
        .environment(\.managedObjectContext, CoreDataStack.preview.viewContext)
}
