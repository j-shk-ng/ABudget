//
//  TransactionFilterView.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Filter sheet for transactions
struct TransactionFilterView: View {
    @ObservedObject var viewModel: TransactionViewModel
    @Environment(\.dismiss) var dismiss

    @State private var categories: [CategoryDTO] = []
    @State private var budgetPeriods: [BudgetPeriodDTO] = []

    var body: some View {
        NavigationStack {
            Form {
                // Date Range Filter
                Section {
                    Picker("Date Range", selection: $viewModel.dateRangeFilter) {
                        ForEach(DateRangeFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }

                    if viewModel.dateRangeFilter == .custom {
                        DatePicker("From", selection: $viewModel.customStartDate, displayedComponents: .date)
                        DatePicker("To", selection: $viewModel.customEndDate, displayedComponents: .date)
                    }
                } header: {
                    Text("Date Range")
                } footer: {
                    if viewModel.dateRangeFilter != .all {
                        Text("Showing transactions from \(viewModel.customStartDate, style: .date) to \(viewModel.customEndDate, style: .date)")
                    }
                }

                // Bucket Filter
                Section {
                    Picker("Bucket Type", selection: $viewModel.selectedBucket) {
                        Text("All Buckets").tag(nil as BucketType?)

                        ForEach([BucketType.needs, .wants, .savings], id: \.self) { bucket in
                            HStack {
                                Image(systemName: bucket.iconName)
                                Text(bucket.displayName)
                            }
                            .tag(bucket as BucketType?)
                        }
                    }
                } header: {
                    Text("Bucket")
                }

                // Category Filter
                Section {
                    Picker("Category", selection: $viewModel.selectedCategoryId) {
                        Text("All Categories").tag(nil as UUID?)

                        ForEach(categories) { category in
                            if category.hasSubcategories {
                                // Parent category header
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
                }

                // Budget Period Filter
                Section {
                    Picker("Budget Period", selection: $viewModel.selectedPeriodId) {
                        Text("All Periods").tag(nil as UUID?)

                        ForEach(budgetPeriods) { period in
                            HStack {
                                Text(period.dateRange)
                                if period.isActive {
                                    Text("(Active)")
                                        .foregroundColor(.green)
                                }
                            }
                            .tag(period.id as UUID?)
                        }
                    }
                } header: {
                    Text("Budget Period")
                }

                // Active filters summary
                if viewModel.activeFilterCount > 0 {
                    Section {
                        HStack {
                            Text("Active Filters")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(viewModel.activeFilterCount)")
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }

                        Button(role: .destructive) {
                            viewModel.clearAllFilters()
                        } label: {
                            Label("Clear All Filters", systemImage: "xmark.circle")
                        }
                    }
                }
            }
            .navigationTitle("Filter Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadFilterData()
            }
        }
    }

    private func loadFilterData() async {
        await loadCategories()
        await loadBudgetPeriods()
    }

    private func loadCategories() async {
        let repository = CoreDataCategoryRepository()
        do {
            categories = try await repository.fetchRootCategories()
        } catch {
            // Silent failure
        }
    }

    private func loadBudgetPeriods() async {
        let repository = CoreDataBudgetPeriodRepository()
        do {
            budgetPeriods = try await repository.fetchAll()
        } catch {
            // Silent failure
        }
    }
}

#Preview {
    TransactionFilterView(viewModel: TransactionViewModel())
}
