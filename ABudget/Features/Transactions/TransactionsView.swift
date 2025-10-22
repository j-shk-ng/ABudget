//
//  TransactionsView.swift
//  ABudget
//
//  Created by Joshua King on 10/20/25.
//

import SwiftUI

/// Main Transactions tab - delegates to TransactionListView
struct TransactionsView: View {

    // MARK: - Body

    var body: some View {
        TransactionListView()
    }
}

// MARK: - Preview

#Preview {
    TransactionsView()
        .environment(\.managedObjectContext, CoreDataStack.preview.viewContext)
}
