//
//  TransactionFormView.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Form view for adding or editing a transaction
struct TransactionFormView: View {
    @ObservedObject var viewModel: TransactionViewModel
    @Environment(\.dismiss) var dismiss

    let transaction: TransactionDTO?

    @State private var subTotal: Decimal
    @State private var tax: Decimal
    @State private var merchant: String
    @State private var date: Date
    @State private var transactionDescription: String
    @State private var selectedCategoryId: UUID?
    @State private var selectedBucket: BucketType

    @State private var categories: [CategoryDTO] = []
    @State private var validationErrors: [String] = []

    init(viewModel: TransactionViewModel, transaction: TransactionDTO?) {
        self.viewModel = viewModel
        self.transaction = transaction

        // Initialize state from transaction or defaults
        _subTotal = State(initialValue: transaction?.subTotal ?? 0)
        _tax = State(initialValue: transaction?.tax ?? 0)
        _merchant = State(initialValue: transaction?.merchant ?? "")
        _date = State(initialValue: transaction?.date ?? Date())
        _transactionDescription = State(initialValue: transaction?.transactionDescription ?? "")
        _selectedCategoryId = State(initialValue: transaction?.categoryId)
        _selectedBucket = State(initialValue: transaction?.bucketType ?? .needs)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Amount Section
                Section {
                    CurrencyTextField(title: "Subtotal", amount: $subTotal)

                    CurrencyTextField(title: "Tax (Optional)", amount: $tax)

                    HStack {
                        Text("Total")
                            .fontWeight(.bold)
                        Spacer()
                        Text(totalAmount, format: .currency(code: "USD"))
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("Amount")
                }

                // Details Section
                Section {
                    TextField("Merchant", text: $merchant)

                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    TextField("Description (Optional)", text: $transactionDescription, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Details")
                }

                // Category Section
                Section {
                    Picker("Category", selection: $selectedCategoryId) {
                        Text("None").tag(nil as UUID?)

                        ForEach(categories) { category in
                            if category.hasSubcategories {
                                // Parent category as section
                                Section(category.name) {
                                    ForEach(category.subcategories) { subcategory in
                                        Text(subcategory.name).tag(subcategory.id as UUID?)
                                    }
                                }
                            } else {
                                Text(category.name).tag(category.id as UUID?)
                            }
                        }
                    }
                } header: {
                    Text("Category")
                } footer: {
                    if selectedCategoryId == nil {
                        Text("Select a category to better track your spending")
                            .foregroundColor(.orange)
                    }
                }

                // Bucket Section
                Section {
                    Picker("Bucket Type", selection: $selectedBucket) {
                        ForEach([BucketType.needs, .wants, .savings], id: \.self) { bucket in
                            HStack {
                                Image(systemName: bucket.iconName)
                                Text(bucket.displayName)
                            }
                            .tag(bucket)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Bucket description
                    HStack(spacing: 8) {
                        Image(systemName: selectedBucket.iconName)
                            .foregroundColor(bucketColor)
                        Text(bucketDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Budget Bucket")
                }

                // Validation Errors
                if !validationErrors.isEmpty {
                    Section {
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
                }
            }
            .navigationTitle(transaction == nil ? "Add Transaction" : "Edit Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelForm()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(transaction == nil ? "Add" : "Save") {
                        Task {
                            await saveTransaction()
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .task {
                await loadCategories()
            }
        }
    }

    // MARK: - Computed Properties

    private var totalAmount: Decimal {
        subTotal + tax
    }

    private var isValid: Bool {
        !merchant.isEmpty && subTotal > 0
    }

    private var bucketColor: Color {
        switch selectedBucket {
        case .needs: return .red
        case .wants: return .orange
        case .savings: return .green
        }
    }

    private var bucketDescription: String {
        switch selectedBucket {
        case .needs:
            return "Essential expenses like groceries, rent, utilities"
        case .wants:
            return "Non-essential purchases like entertainment, dining out"
        case .savings:
            return "Money set aside for future goals or emergencies"
        }
    }

    // MARK: - Methods

    private func saveTransaction() async {
        validationErrors = []

        // Validate
        guard !merchant.isEmpty else {
            validationErrors.append("Merchant name is required")
            return
        }

        guard subTotal > 0 else {
            validationErrors.append("Subtotal must be greater than 0")
            return
        }

        // Create or update transaction
        let transactionDTO = TransactionDTO(
            id: transaction?.id ?? UUID(),
            subTotal: subTotal,
            tax: tax,
            merchant: merchant,
            date: date,
            transactionDescription: transactionDescription.isEmpty ? nil : transactionDescription,
            budgetPeriodId: nil, // Will be auto-assigned by ViewModel
            categoryId: selectedCategoryId,
            bucketType: selectedBucket,
            createdAt: transaction?.createdAt ?? Date()
        )

        let success: Bool
        if transaction == nil {
            success = await viewModel.addTransaction(transactionDTO)
        } else {
            success = await viewModel.updateTransaction(transactionDTO)
        }

        if success {
            dismiss()
        }
    }

    private func loadCategories() async {
        let repository = CoreDataCategoryRepository()
        do {
            categories = try await repository.fetchRootCategories()
        } catch {
            // Silent failure - just no categories to select
        }
    }
}

#Preview("Add Transaction") {
    TransactionFormView(
        viewModel: TransactionViewModel(),
        transaction: nil
    )
}

#Preview("Edit Transaction") {
    TransactionFormView(
        viewModel: TransactionViewModel(),
        transaction: TransactionDTO(
            subTotal: 45.99,
            tax: 4.14,
            merchant: "Whole Foods",
            date: Date(),
            transactionDescription: "Weekly groceries",
            budgetPeriodId: UUID(),
            categoryId: UUID(),
            bucketType: .needs
        )
    )
}
