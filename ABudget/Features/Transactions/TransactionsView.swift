//
//  TransactionsView.swift
//  ABudget
//
//  Created by Joshua King on 10/20/25.
//

import SwiftUI

struct TransactionsView: View {

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                Text("Transactions")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()
            }
            .navigationTitle("Transactions")
        }
    }
}

// MARK: - Preview

#Preview {
    TransactionsView()
}
