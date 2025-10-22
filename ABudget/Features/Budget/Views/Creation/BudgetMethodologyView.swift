//
//  BudgetMethodologyView.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Step 1: Budget methodology selection view
struct BudgetMethodologyView: View {
    @Binding var selectedMethodology: BudgetMethodology

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Choose Your Budget Method")
                .font(.title2)
                .fontWeight(.bold)

            Text("Select the budgeting methodology that best fits your financial planning style.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                ForEach([BudgetMethodology.zeroBased, .envelope, .percentage], id: \.self) { methodology in
                    MethodologyCard(
                        methodology: methodology,
                        isSelected: selectedMethodology == methodology,
                        action: {
                            selectedMethodology = methodology
                        }
                    )
                }
            }

            Spacer()
        }
        .padding()
    }
}

/// Card for displaying and selecting a budget methodology
struct MethodologyCard: View {
    let methodology: BudgetMethodology
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(methodology.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                                .font(.title3)
                        }
                    }

                    Text(descriptionFor(methodology))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(uiColor: .systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func descriptionFor(_ methodology: BudgetMethodology) -> String {
        switch methodology {
        case .zeroBased:
            return "Allocate every dollar of income to a specific category. Great for those who want complete control and accountability."
        case .envelope:
            return "Divide your money into category 'envelopes'. Once an envelope is empty, no more spending in that category."
        case .percentage:
            return "Split your income by percentages (50/30/20 rule). Allocate 50% to needs, 30% to wants, and 20% to savings."
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var methodology: BudgetMethodology = .zeroBased

        var body: some View {
            NavigationStack {
                BudgetMethodologyView(selectedMethodology: $methodology)
            }
        }
    }

    return PreviewWrapper()
}
