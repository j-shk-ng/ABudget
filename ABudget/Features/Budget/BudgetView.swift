//
//  BudgetView.swift
//  ABudget
//
//  Created by Joshua King on 10/20/25.
//

import SwiftUI

struct BudgetView: View {

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                Text("Budget")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()
            }
            .navigationTitle("Budget")
        }
    }
}

// MARK: - Preview

#Preview {
    BudgetView()
}
