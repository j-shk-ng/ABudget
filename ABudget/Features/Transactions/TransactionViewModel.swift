//
//  TransactionViewModel.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import Combine

/// ViewModel for managing transactions with filtering and sorting
@MainActor
final class TransactionViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var transactions: [TransactionDTO] = []
    @Published var filteredTransactions: [TransactionDTO] = []
    @Published var isLoading = false
    @Published var error: AppError?

    // Filter state
    @Published var searchText: String = ""
    @Published var selectedCategoryId: UUID?
    @Published var selectedBucket: BucketType?
    @Published var selectedPeriodId: UUID?
    @Published var dateRangeFilter: DateRangeFilter = .all
    @Published var customStartDate: Date = Date()
    @Published var customEndDate: Date = Date()

    // Sort state
    @Published var sortOption: SortOption = .dateDescending

    // Form state
    @Published var showingFormSheet = false
    @Published var editingTransaction: TransactionDTO?

    // MARK: - Dependencies

    private let transactionRepository: TransactionRepository
    private let budgetPeriodRepository: BudgetPeriodRepository
    private let categoryRepository: CategoryRepository
    private let transactionAssigner: TransactionAssigner

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        transactionRepository: TransactionRepository = CoreDataTransactionRepository(),
        budgetPeriodRepository: BudgetPeriodRepository = CoreDataBudgetPeriodRepository(),
        categoryRepository: CategoryRepository = CoreDataCategoryRepository(),
        transactionAssigner: TransactionAssigner = TransactionAssigner()
    ) {
        self.transactionRepository = transactionRepository
        self.budgetPeriodRepository = budgetPeriodRepository
        self.categoryRepository = categoryRepository
        self.transactionAssigner = transactionAssigner

        setupFilterObservers()
    }

    // MARK: - Load Methods

    func loadTransactions() async {
        isLoading = true
        error = nil

        do {
            transactions = try await transactionRepository.fetchAll()
            applyFiltersAndSort()
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .unknown(error)
        }

        isLoading = false
    }

    func loadTransactions(forPeriodId periodId: UUID) async {
        isLoading = true
        error = nil

        do {
            transactions = try await transactionRepository.fetchTransactions(forBudgetPeriodId: periodId)
            applyFiltersAndSort()
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .unknown(error)
        }

        isLoading = false
    }

    // MARK: - CRUD Operations

    func addTransaction(_ transaction: TransactionDTO) async -> Bool {
        isLoading = true
        error = nil

        do {
            // Auto-assign to budget period based on date
            let budgetPeriodId = try await assignToBudgetPeriod(date: transaction.date)

            // Create transaction with assigned period
            var transactionToCreate = transaction
            transactionToCreate = TransactionDTO(
                subTotal: transaction.subTotal,
                tax: transaction.tax,
                merchant: transaction.merchant,
                date: transaction.date,
                transactionDescription: transaction.transactionDescription,
                budgetPeriodId: budgetPeriodId,
                categoryId: transaction.categoryId,
                bucketType: transaction.bucketType
            )

            _ = try await transactionRepository.create(transactionToCreate)
            await loadTransactions()

            isLoading = false
            return true
        } catch let appError as AppError {
            error = appError
            isLoading = false
            return false
        } catch {
            self.error = .unknown(error)
            isLoading = false
            return false
        }
    }

    func updateTransaction(_ transaction: TransactionDTO) async -> Bool {
        isLoading = true
        error = nil

        do {
            // Re-assign to budget period if date changed
            let budgetPeriodId = try await assignToBudgetPeriod(date: transaction.date)

            var updatedTransaction = transaction
            updatedTransaction = TransactionDTO(
                id: transaction.id,
                subTotal: transaction.subTotal,
                tax: transaction.tax,
                merchant: transaction.merchant,
                date: transaction.date,
                transactionDescription: transaction.transactionDescription,
                budgetPeriodId: budgetPeriodId,
                categoryId: transaction.categoryId,
                bucketType: transaction.bucketType,
                createdAt: transaction.createdAt
            )

            try await transactionRepository.update(updatedTransaction)
            await loadTransactions()

            isLoading = false
            return true
        } catch let appError as AppError {
            error = appError
            isLoading = false
            return false
        } catch {
            self.error = .unknown(error)
            isLoading = false
            return false
        }
    }

    func deleteTransaction(_ transaction: TransactionDTO) async -> Bool {
        isLoading = true
        error = nil

        do {
            try await transactionRepository.delete(transaction.id)
            await loadTransactions()

            isLoading = false
            return true
        } catch let appError as AppError {
            error = appError
            isLoading = false
            return false
        } catch {
            self.error = .unknown(error)
            isLoading = false
            return false
        }
    }

    // MARK: - Form Actions

    func startAddingTransaction() {
        editingTransaction = nil
        showingFormSheet = true
    }

    func startEditing(_ transaction: TransactionDTO) {
        editingTransaction = transaction
        showingFormSheet = true
    }

    func cancelForm() {
        editingTransaction = nil
        showingFormSheet = false
    }

    // MARK: - Filter Actions

    func clearAllFilters() {
        searchText = ""
        selectedCategoryId = nil
        selectedBucket = nil
        selectedPeriodId = nil
        dateRangeFilter = .all
    }

    func setDateRangeFilter(_ filter: DateRangeFilter) {
        dateRangeFilter = filter

        switch filter {
        case .thisMonth:
            let calendar = Calendar.current
            let now = Date()
            customStartDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            customEndDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: customStartDate)!
        case .lastMonth:
            let calendar = Calendar.current
            let now = Date()
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now)!
            customStartDate = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth))!
            customEndDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: customStartDate)!
        case .custom, .all:
            break
        }
    }

    var activeFilterCount: Int {
        var count = 0
        if !searchText.isEmpty { count += 1 }
        if selectedCategoryId != nil { count += 1 }
        if selectedBucket != nil { count += 1 }
        if selectedPeriodId != nil { count += 1 }
        if dateRangeFilter != .all { count += 1 }
        return count
    }

    // MARK: - Private Methods

    private func setupFilterObservers() {
        // Observe filter changes and re-apply filters
        Publishers.CombineLatest4(
            $searchText,
            $selectedCategoryId,
            $selectedBucket,
            $selectedPeriodId
        )
        .debounce(for: 0.3, scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            self?.applyFiltersAndSort()
        }
        .store(in: &cancellables)

        Publishers.CombineLatest3(
            $dateRangeFilter,
            $customStartDate,
            $customEndDate
        )
        .debounce(for: 0.3, scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            self?.applyFiltersAndSort()
        }
        .store(in: &cancellables)

        $sortOption
            .sink { [weak self] _ in
                self?.applyFiltersAndSort()
            }
            .store(in: &cancellables)
    }

    private func applyFiltersAndSort() {
        var filtered = transactions

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { transaction in
                transaction.merchant.localizedCaseInsensitiveContains(searchText) ||
                (transaction.transactionDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Apply category filter
        if let categoryId = selectedCategoryId {
            filtered = filtered.filterByCategory(categoryId)
        }

        // Apply bucket filter
        if let bucket = selectedBucket {
            filtered = filtered.filterByBucket(bucket)
        }

        // Apply period filter
        if let periodId = selectedPeriodId {
            filtered = filtered.filter { $0.budgetPeriodId == periodId }
        }

        // Apply date range filter
        switch dateRangeFilter {
        case .thisMonth, .lastMonth, .custom:
            filtered = filtered.filter { transaction in
                transaction.date >= customStartDate && transaction.date <= customEndDate
            }
        case .all:
            break
        }

        // Apply sort
        filtered = sort(filtered, by: sortOption)

        filteredTransactions = filtered
    }

    private func sort(_ transactions: [TransactionDTO], by option: SortOption) -> [TransactionDTO] {
        switch option {
        case .dateDescending:
            return transactions.sortedByDate(ascending: false)
        case .dateAscending:
            return transactions.sortedByDate(ascending: true)
        case .amountDescending:
            return transactions.sorted { $0.total > $1.total }
        case .amountAscending:
            return transactions.sorted { $0.total < $1.total }
        case .merchantAZ:
            return transactions.sorted { $0.merchant < $1.merchant }
        case .merchantZA:
            return transactions.sorted { $0.merchant > $1.merchant }
        }
    }

    private func assignToBudgetPeriod(date: Date) async throws -> UUID? {
        let periods = try await budgetPeriodRepository.fetchAll()

        // Create a temporary transaction to use with assigner
        let tempTransaction = TransactionDTO(
            subTotal: 0,
            tax: 0,
            merchant: "",
            date: date,
            transactionDescription: nil,
            budgetPeriodId: nil,
            categoryId: nil,
            bucketType: .needs
        )

        let assignedPeriod = transactionAssigner.assignTransactionToBudgetPeriod(
            transaction: tempTransaction,
            periods: periods
        )

        return assignedPeriod?.id
    }
}

// MARK: - Supporting Types

enum DateRangeFilter: String, CaseIterable {
    case all = "All Time"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case custom = "Custom Range"
}

enum SortOption: String, CaseIterable {
    case dateDescending = "Newest First"
    case dateAscending = "Oldest First"
    case amountDescending = "Highest Amount"
    case amountAscending = "Lowest Amount"
    case merchantAZ = "Merchant A-Z"
    case merchantZA = "Merchant Z-A"
}
