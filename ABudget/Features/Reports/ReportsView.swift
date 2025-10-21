//
//  ReportsView.swift
//  ABudget
//
//  Created by Joshua King on 10/20/25.
//

import SwiftUI

struct ReportsView: View {

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                Text("Reports")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()
            }
            .navigationTitle("Reports")
        }
    }
}

// MARK: - Preview

#Preview {
    ReportsView()
}
