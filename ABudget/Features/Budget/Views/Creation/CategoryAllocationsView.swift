//
//  CategoryAllocationsView.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Step 4: Category allocations entry view
struct CategoryAllocationsView: View {
    @Binding var allocations: [CategoryAllocationDraft]
    let categories: [CategoryDTO]
    let totalIncome: Decimal
    let onUpdateAllocation: (UUID, Decimal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Allocate Your Budget")
                .font(.title2)
                .fontWeight(.bold)

            Text("Assign amounts to each category. This step is optional - you can set these later.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Budget summary card
            BudgetSummaryCard(
                totalIncome: totalIncome,
                totalAllocated: totalAllocated,
                remaining: remainingToAllocate
            )

            // Allocations list
            if categories.isEmpty {
                EmptyCategoriesView()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(categories) { category in
                            CategoryAllocationRow(
                                category: category,
                                allocation: allocations.first { $0.categoryId == category.id },
                                onUpdateAllocation: { amount in
                                    onUpdateAllocation(category.id, amount)
                                }
                            )
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    private var totalAllocated: Decimal {
        allocations.reduce(0) { $0 + $1.plannedAmount }
    }

    private var remainingToAllocate: Decimal {
        totalIncome - totalAllocated
    }
}

/// Summary card showing budget allocation progress
struct BudgetSummaryCard: View {
    let totalIncome: Decimal
    let totalAllocated: Decimal
    let remaining: Decimal

    var body: some View {
        VStack(spacing: 16) {
            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Budget Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(allocationPercentage, specifier: "%.1f")%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(progressColor)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)

                        Rectangle()
                            .fill(progressColor)
                            .frame(width: min(progressWidth(geometry.size.width), geometry.size.width), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }

            Divider()

            // Budget breakdown
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Income")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(totalIncome, format: .currency(code: "USD"))
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Allocated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(totalAllocated, format: .currency(code: "USD"))
                        .font(.headline)
                        .foregroundColor(progressColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(remaining, format: .currency(code: "USD"))
                        .font(.headline)
                        .foregroundColor(remaining < 0 ? .red : .green)
                }
            }

            // Warning if over-allocated
            if remaining < 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("You've allocated more than your total income")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(12)
    }

    private var allocationPercentage: Double {
        guard totalIncome > 0 else { return 0 }
        return Double(truncating: (totalAllocated / totalIncome * 100) as NSDecimalNumber)
    }

    private func progressWidth(_ totalWidth: CGFloat) -> CGFloat {
        guard totalIncome > 0 else { return 0 }
        let percentage = Double(truncating: (totalAllocated / totalIncome) as NSDecimalNumber)
        return totalWidth * CGFloat(percentage)
    }

    private var progressColor: Color {
        if remaining < 0 {
            return .red
        } else if remaining == 0 {
            return .green
        } else {
            return .blue
        }
    }
}

/// Row for a single category allocation
struct CategoryAllocationRow: View {
    let category: CategoryDTO
    let allocation: CategoryAllocationDraft?
    let onUpdateAllocation: (Decimal) -> Void

    @State private var amount: Decimal

    init(category: CategoryDTO, allocation: CategoryAllocationDraft?, onUpdateAllocation: @escaping (Decimal) -> Void) {
        self.category = category
        self.allocation = allocation
        self.onUpdateAllocation = onUpdateAllocation
        _amount = State(initialValue: allocation?.plannedAmount ?? 0)
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if category.hasSubcategories {
                    Text("\(category.subcategoryCount) subcategories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            CurrencyTextField(title: "Amount", amount: $amount)
                .frame(width: 140)
                .textFieldStyle(.roundedBorder)
                .onChange(of: amount) { _, newValue in
                    onUpdateAllocation(newValue)
                }
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(8)
    }
}

/// Empty state view when no categories exist
struct EmptyCategoriesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Categories Yet")
                .font(.headline)

            Text("Create categories in Settings first, then return to allocate your budget.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink(destination: Text("Settings")) {
                HStack {
                    Image(systemName: "gear")
                    Text("Go to Settings")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var allocations: [CategoryAllocationDraft] = [
            CategoryAllocationDraft(categoryId: UUID(), plannedAmount: 2000),
            CategoryAllocationDraft(categoryId: UUID(), plannedAmount: 1500)
        ]

        let categories = [
            CategoryDTO(id: UUID(), name: "Groceries", sortOrder: 0),
            CategoryDTO(id: UUID(), name: "Transportation", sortOrder: 1),
            CategoryDTO(id: UUID(), name: "Entertainment", sortOrder: 2)
        ]

        var body: some View {
            NavigationStack {
                CategoryAllocationsView(
                    allocations: $allocations,
                    categories: categories,
                    totalIncome: 5000,
                    onUpdateAllocation: { categoryId, amount in
                        if let index = allocations.firstIndex(where: { $0.categoryId == categoryId }) {
                            allocations[index] = CategoryAllocationDraft(
                                categoryId: categoryId,
                                plannedAmount: amount,
                                carryOverAmount: allocations[index].carryOverAmount
                            )
                        } else {
                            allocations.append(CategoryAllocationDraft(categoryId: categoryId, plannedAmount: amount))
                        }
                    }
                )
            }
        }
    }

    return PreviewWrapper()
}
