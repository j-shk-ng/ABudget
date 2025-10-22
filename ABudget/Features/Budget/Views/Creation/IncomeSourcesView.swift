//
//  IncomeSourcesView.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Step 3: Income sources entry view
struct IncomeSourcesView: View {
    @Binding var incomeSources: [IncomeSourceDraft]
    @Binding var validationErrors: [String]
    let onAdd: () -> Void
    let onRemove: (Int) -> Void
    let onUpdate: (Int, String?, Decimal?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Add Income Sources")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter all sources of income for this budget period. You can add multiple income sources.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Income sources list
            if incomeSources.isEmpty {
                EmptyIncomeSourcesView(onAdd: onAdd)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(incomeSources.enumerated()), id: \.offset) { index, income in
                            IncomeSourceRow(
                                income: income,
                                onUpdateName: { newName in
                                    onUpdate(index, newName, nil)
                                },
                                onUpdateAmount: { newAmount in
                                    onUpdate(index, nil, newAmount)
                                },
                                onRemove: {
                                    onRemove(index)
                                }
                            )
                        }

                        // Add another button
                        Button(action: onAdd) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Another Income Source")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }

            // Total income summary
            if !incomeSources.isEmpty {
                Divider()

                HStack {
                    Text("Total Income")
                        .font(.headline)
                    Spacer()
                    Text(totalIncome, format: .currency(code: "USD"))
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(8)
            }

            // Validation errors
            if !validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(validationErrors, id: \.self) { error in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
    }

    private var totalIncome: Decimal {
        incomeSources.reduce(0) { $0 + $1.amount }
    }
}

/// Row for a single income source
struct IncomeSourceRow: View {
    let income: IncomeSourceDraft
    let onUpdateName: (String) -> Void
    let onUpdateAmount: (Decimal) -> Void
    let onRemove: () -> Void

    @State private var sourceName: String
    @State private var amount: Decimal

    init(income: IncomeSourceDraft, onUpdateName: @escaping (String) -> Void, onUpdateAmount: @escaping (Decimal) -> Void, onRemove: @escaping () -> Void) {
        self.income = income
        self.onUpdateName = onUpdateName
        self.onUpdateAmount = onUpdateAmount
        self.onRemove = onRemove
        _sourceName = State(initialValue: income.sourceName)
        _amount = State(initialValue: income.amount)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Source Name (e.g., Salary)", text: $sourceName)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: sourceName) { _, newValue in
                        onUpdateName(newValue)
                    }

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }

            CurrencyTextField(title: "Amount", amount: $amount)
                .textFieldStyle(.roundedBorder)
                .onChange(of: amount) { _, newValue in
                    onUpdateAmount(newValue)
                }
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
        .cornerRadius(8)
    }
}

/// Empty state view for income sources
struct EmptyIncomeSourcesView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "banknote")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Income Sources Yet")
                .font(.headline)

            Text("Add your first income source to get started with your budget.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onAdd) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Income Source")
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
        @State private var incomeSources: [IncomeSourceDraft] = [
            IncomeSourceDraft(sourceName: "Salary", amount: 5000),
            IncomeSourceDraft(sourceName: "Freelance", amount: 1500)
        ]
        @State private var errors: [String] = []

        var body: some View {
            NavigationStack {
                IncomeSourcesView(
                    incomeSources: $incomeSources,
                    validationErrors: $errors,
                    onAdd: {
                        incomeSources.append(IncomeSourceDraft(sourceName: "", amount: 0))
                    },
                    onRemove: { index in
                        incomeSources.remove(at: index)
                    },
                    onUpdate: { index, name, amount in
                        if let name = name {
                            incomeSources[index] = IncomeSourceDraft(
                                sourceName: name,
                                amount: incomeSources[index].amount,
                                originalId: incomeSources[index].originalId
                            )
                        }
                        if let amount = amount {
                            incomeSources[index] = IncomeSourceDraft(
                                sourceName: incomeSources[index].sourceName,
                                amount: amount,
                                originalId: incomeSources[index].originalId
                            )
                        }
                    }
                )
            }
        }
    }

    return PreviewWrapper()
}
