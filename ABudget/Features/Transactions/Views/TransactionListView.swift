//
//  TransactionListView.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Main Transactions tab view
struct TransactionListView: View {
    @StateObject private var viewModel = TransactionViewModel()
    @State private var categories: [CategoryDTO] = []
    @State private var showingFilterSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.transactions.isEmpty {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else if viewModel.filteredTransactions.isEmpty {
                    EmptyTransactionsView(
                        hasFilters: viewModel.activeFilterCount > 0,
                        onAddTransaction: {
                            viewModel.startAddingTransaction()
                        },
                        onClearFilters: {
                            viewModel.clearAllFilters()
                        }
                    )
                } else {
                    TransactionListContent(
                        viewModel: viewModel,
                        categories: categories
                    )
                }
            }
            .navigationTitle("Transactions")
            .searchable(text: $viewModel.searchText, prompt: "Search merchant or description")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            viewModel.startAddingTransaction()
                        } label: {
                            Label("Add Transaction", systemImage: "plus")
                        }

                        Divider()

                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button {
                                    viewModel.sortOption = option
                                } label: {
                                    HStack {
                                        Text(option.rawValue)
                                        if viewModel.sortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }

                        Button {
                            showingFilterSheet = true
                        } label: {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingFormSheet) {
                TransactionFormView(
                    viewModel: viewModel,
                    transaction: viewModel.editingTransaction
                )
            }
            .sheet(isPresented: $showingFilterSheet) {
                TransactionFilterView(viewModel: viewModel)
            }
            .task {
                await loadData()
            }
            .refreshable {
                await loadData()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.activeFilterCount > 0 {
                    FilterChipsBar(viewModel: viewModel)
                        .padding()
                }
            }
        }
    }

    private func loadData() async {
        await viewModel.loadTransactions()
        await loadCategories()
    }

    private func loadCategories() async {
        let repository = CoreDataCategoryRepository()
        do {
            categories = try await repository.fetchAll()
        } catch {
            // Silent failure - categories just won't show names
        }
    }
}

/// Content view showing the list of transactions
struct TransactionListContent: View {
    @ObservedObject var viewModel: TransactionViewModel
    let categories: [CategoryDTO]

    var body: some View {
        List {
            ForEach(viewModel.filteredTransactions) { transaction in
                TransactionRow(
                    transaction: transaction,
                    category: categories.first { $0.id == transaction.categoryId }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.startEditing(transaction)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteTransaction(transaction)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        viewModel.startEditing(transaction)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
    }
}

/// Filter chips bar showing active filters
struct FilterChipsBar: View {
    @ObservedObject var viewModel: TransactionViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Active filter count
                Text("\(viewModel.activeFilterCount) active")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !viewModel.searchText.isEmpty {
                    FilterChip(
                        text: "Search: \(viewModel.searchText)",
                        onRemove: { viewModel.searchText = "" }
                    )
                }

                if viewModel.selectedBucket != nil {
                    FilterChip(
                        text: viewModel.selectedBucket!.displayName,
                        onRemove: { viewModel.selectedBucket = nil }
                    )
                }

                if viewModel.dateRangeFilter != .all {
                    FilterChip(
                        text: viewModel.dateRangeFilter.rawValue,
                        onRemove: { viewModel.dateRangeFilter = .all }
                    )
                }

                Button {
                    viewModel.clearAllFilters()
                } label: {
                    Text("Clear All")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
}

/// Individual filter chip
struct FilterChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }
}

/// Empty state view
struct EmptyTransactionsView: View {
    let hasFilters: Bool
    let onAddTransaction: () -> Void
    let onClearFilters: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: hasFilters ? "magnifyingglass" : "cart")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                Text(hasFilters ? "No Transactions Found" : "No Transactions Yet")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(hasFilters
                     ? "Try adjusting your filters to see more results."
                     : "Start tracking your spending by adding your first transaction.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if hasFilters {
                Button(action: onClearFilters) {
                    Text("Clear Filters")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: 280)
                        .background(Color.red)
                        .cornerRadius(12)
                }
            } else {
                Button(action: onAddTransaction) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Transaction")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 280)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
        }
        .padding()
    }
}

#Preview {
    TransactionListView()
}
