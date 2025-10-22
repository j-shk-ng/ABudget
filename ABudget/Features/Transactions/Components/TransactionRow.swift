//
//  TransactionRow.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Row component for displaying a single transaction
struct TransactionRow: View {
    let transaction: TransactionDTO
    let category: CategoryDTO?

    var body: some View {
        HStack(spacing: 12) {
            // Bucket color indicator
            Rectangle()
                .fill(bucketColor)
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 4) {
                // Merchant name
                Text(transaction.merchant)
                    .font(.headline)
                    .foregroundColor(.primary)

                // Category and date
                HStack(spacing: 8) {
                    if let category = category {
                        Label(category.name, systemImage: "folder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(transaction.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Description if available
                if let description = transaction.transactionDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Amount with bucket indicator
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.total, format: .currency(code: "USD"))
                    .font(.headline)
                    .foregroundColor(.primary)

                // Bucket badge
                Text(transaction.bucketType.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(bucketColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(bucketColor.opacity(0.2))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 8)
    }

    private var bucketColor: Color {
        switch transaction.bucketType {
        case .needs:
            return .red
        case .wants:
            return .orange
        case .savings:
            return .green
        }
    }
}

#Preview {
    List {
        TransactionRow(
            transaction: TransactionDTO(
                subTotal: 45.99,
                tax: 4.14,
                merchant: "Whole Foods",
                date: Date(),
                transactionDescription: "Weekly groceries",
                budgetPeriodId: UUID(),
                categoryId: UUID(),
                bucketType: .needs
            ),
            category: CategoryDTO(name: "Groceries")
        )

        TransactionRow(
            transaction: TransactionDTO(
                subTotal: 29.99,
                tax: 0,
                merchant: "Netflix",
                date: Date(),
                transactionDescription: nil,
                budgetPeriodId: UUID(),
                categoryId: UUID(),
                bucketType: .wants
            ),
            category: CategoryDTO(name: "Entertainment")
        )

        TransactionRow(
            transaction: TransactionDTO(
                subTotal: 500.00,
                tax: 0,
                merchant: "Savings Transfer",
                date: Date(),
                transactionDescription: "Emergency fund",
                budgetPeriodId: UUID(),
                categoryId: UUID(),
                bucketType: .savings
            ),
            category: CategoryDTO(name: "Savings")
        )
    }
}
