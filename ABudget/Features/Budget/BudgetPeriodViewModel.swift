//
//  BudgetPeriodViewModel.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import Combine

/// ViewModel for managing budget period creation and list
@MainActor
final class BudgetPeriodViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var budgetPeriods: [BudgetPeriodDTO] = []
    @Published var selectedPeriod: BudgetPeriodDTO?
    @Published var isLoading = false
    @Published var error: AppError?

    // Creation flow state
    @Published var currentStep: CreationStep = .methodology
    @Published var selectedMethodology: BudgetMethodology = .zeroBased
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
    @Published var incomeSources: [IncomeSourceDraft] = []
    @Published var allocations: [CategoryAllocationDraft] = []

    // UI state
    @Published var showingCreationSheet = false
    @Published var validationErrors: [String] = []

    // MARK: - Dependencies

    private let budgetRepository: BudgetPeriodRepository
    private let allocationRepository: CategoryAllocationRepository
    private let transactionRepository: TransactionRepository
    private let categoryRepository: CategoryRepository
    private let prefiller: BudgetPrefiller
    private let calculator: BudgetCalculator

    // MARK: - Initialization

    init(
        budgetRepository: BudgetPeriodRepository = CoreDataBudgetPeriodRepository(),
        allocationRepository: CategoryAllocationRepository = CoreDataCategoryAllocationRepository(),
        transactionRepository: TransactionRepository = CoreDataTransactionRepository(),
        categoryRepository: CategoryRepository = CoreDataCategoryRepository(),
        prefiller: BudgetPrefiller = BudgetPrefiller(),
        calculator: BudgetCalculator = BudgetCalculator()
    ) {
        self.budgetRepository = budgetRepository
        self.allocationRepository = allocationRepository
        self.transactionRepository = transactionRepository
        self.categoryRepository = categoryRepository
        self.prefiller = prefiller
        self.calculator = calculator
    }

    // MARK: - Load Methods

    func loadExistingPeriods() async {
        isLoading = true
        error = nil

        do {
            budgetPeriods = try await budgetRepository.fetchAll()

            // Auto-select active period or most recent
            if selectedPeriod == nil {
                selectedPeriod = budgetPeriods.first { $0.isActive } ?? budgetPeriods.first
            }
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .unknown(error)
        }

        isLoading = false
    }

    func loadPeriodDetails(periodId: UUID) async {
        guard let period = budgetPeriods.first(where: { $0.id == periodId }) else { return }
        selectedPeriod = period
    }

    // MARK: - Creation Flow

    func startCreation() {
        resetCreationState()
        showingCreationSheet = true

        // Prefill from previous period if exists
        Task {
            await prefillFromPrevious()
        }
    }

    func prefillFromPrevious() async {
        guard let mostRecentPeriod = budgetPeriods.first else {
            // No previous period, set defaults
            incomeSources = []
            allocations = []
            return
        }

        do {
            // Fetch allocations and transactions from previous period
            let previousAllocations = try await allocationRepository.fetchAllocations(forBudgetPeriodId: mostRecentPeriod.id)
            let previousTransactions = try await transactionRepository.fetchTransactions(forBudgetPeriodId: mostRecentPeriod.id)

            // Use prefiller to create draft
            let draft = prefiller.prefillNewBudgetPeriod(
                from: mostRecentPeriod,
                allocations: previousAllocations,
                transactions: previousTransactions,
                startDate: startDate,
                endDate: endDate
            )

            // Update state
            selectedMethodology = draft.methodology
            incomeSources = draft.incomeSources
            allocations = draft.allocations
        } catch {
            // If prefill fails, just use empty state
            incomeSources = []
            allocations = []
        }
    }

    func createBudgetPeriod() async -> Bool {
        validationErrors = []

        // Create draft
        let draft = BudgetPeriodDraft(
            methodology: selectedMethodology,
            startDate: startDate,
            endDate: endDate,
            incomeSources: incomeSources,
            allocations: allocations
        )

        // Validate
        let validation = prefiller.validateDraft(draft)
        if !validation.isValid {
            validationErrors = validation.errors
            return false
        }

        // Additional validation: check for overlaps
        do {
            let existingPeriods = try await budgetRepository.fetchAll()
            let newPeriod = BudgetPeriodDTO(
                methodology: selectedMethodology,
                startDate: startDate,
                endDate: endDate,
                incomeSources: incomeSources.map { draft in
                    IncomeSourceDTO(sourceName: draft.sourceName, amount: draft.amount)
                }
            )

            try ValidationRules.validateBudgetPeriodNoOverlap(newPeriod, against: existingPeriods)
        } catch let validationError as ValidationError {
            validationErrors = [validationError.localizedDescription]
            return false
        } catch {
            validationErrors = ["Failed to validate period: \(error.localizedDescription)"]
            return false
        }

        // Create period
        isLoading = true

        do {
            // Create budget period
            let newPeriod = BudgetPeriodDTO(
                methodology: selectedMethodology,
                startDate: startDate,
                endDate: endDate,
                incomeSources: incomeSources.map { draft in
                    IncomeSourceDTO(sourceName: draft.sourceName, amount: draft.amount)
                }
            )

            let createdPeriod = try await budgetRepository.create(newPeriod)

            // Create allocations
            for allocationDraft in allocations {
                let allocation = CategoryAllocationDTO(
                    plannedAmount: allocationDraft.plannedAmount,
                    carryOverAmount: allocationDraft.carryOverAmount,
                    budgetPeriodId: createdPeriod.id,
                    categoryId: allocationDraft.categoryId
                )
                _ = try await allocationRepository.create(allocation)
            }

            // Reload periods
            await loadExistingPeriods()

            // Select the new period
            selectedPeriod = budgetPeriods.first { $0.id == createdPeriod.id }

            // Close sheet
            showingCreationSheet = false
            resetCreationState()

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

    // MARK: - Navigation

    func nextStep() {
        guard let next = currentStep.next else { return }

        // Validate current step before proceeding
        if validateCurrentStep() {
            currentStep = next
        }
    }

    func previousStep() {
        guard let previous = currentStep.previous else { return }
        currentStep = previous
        validationErrors = []
    }

    func cancelCreation() {
        showingCreationSheet = false
        resetCreationState()
    }

    private func validateCurrentStep() -> Bool {
        validationErrors = []

        switch currentStep {
        case .methodology:
            // Always valid
            return true

        case .dateRange:
            do {
                try ValidationRules.validateDateRange(startDate: startDate, endDate: endDate)
                return true
            } catch let error as ValidationError {
                validationErrors = [error.localizedDescription]
                return false
            } catch {
                validationErrors = ["Invalid date range"]
                return false
            }

        case .incomeSources:
            if incomeSources.isEmpty {
                validationErrors = ["At least one income source is required"]
                return false
            }

            for income in incomeSources {
                do {
                    try ValidationRules.validateIncomeSource(IncomeSourceDTO(sourceName: income.sourceName, amount: income.amount))
                } catch let error as ValidationError {
                    validationErrors.append(error.localizedDescription)
                }
            }

            return validationErrors.isEmpty

        case .allocations:
            // Allocations are optional
            return true
        }
    }

    // MARK: - Income Management

    func addIncome() {
        incomeSources.append(IncomeSourceDraft(sourceName: "", amount: 0))
    }

    func removeIncome(at index: Int) {
        guard index < incomeSources.count else { return }
        incomeSources.remove(at: index)
    }

    func updateIncome(at index: Int, sourceName: String?, amount: Decimal?) {
        guard index < incomeSources.count else { return }

        if let sourceName = sourceName {
            incomeSources[index] = IncomeSourceDraft(
                sourceName: sourceName,
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

    // MARK: - Allocation Management

    func loadCategoriesForAllocation() async {
        do {
            let categories = try await categoryRepository.fetchRootCategories()

            // Create allocations for categories that don't have one yet
            let existingCategoryIds = Set(allocations.map { $0.categoryId })

            for category in categories {
                if !existingCategoryIds.contains(category.id) {
                    allocations.append(CategoryAllocationDraft(
                        categoryId: category.id,
                        plannedAmount: 0,
                        carryOverAmount: 0
                    ))
                }
            }
        } catch {
            // Silent failure - allocations step is optional
        }
    }

    func updateAllocation(for categoryId: UUID, plannedAmount: Decimal) {
        if let index = allocations.firstIndex(where: { $0.categoryId == categoryId }) {
            allocations[index] = CategoryAllocationDraft(
                categoryId: categoryId,
                plannedAmount: plannedAmount,
                carryOverAmount: allocations[index].carryOverAmount,
                originalAllocationId: allocations[index].originalAllocationId
            )
        }
    }

    // MARK: - Helper Methods

    private func resetCreationState() {
        currentStep = .methodology
        selectedMethodology = .zeroBased
        startDate = Date()
        endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        incomeSources = []
        allocations = []
        validationErrors = []
    }

    var totalIncome: Decimal {
        incomeSources.reduce(0) { $0 + $1.amount }
    }

    var totalPlanned: Decimal {
        allocations.reduce(0) { $0 + $1.plannedAmount }
    }

    var remainingToAllocate: Decimal {
        totalIncome - totalPlanned
    }
}

// MARK: - Creation Steps

enum CreationStep: Int, CaseIterable {
    case methodology = 0
    case dateRange = 1
    case incomeSources = 2
    case allocations = 3

    var title: String {
        switch self {
        case .methodology: return "Budget Method"
        case .dateRange: return "Date Range"
        case .incomeSources: return "Income Sources"
        case .allocations: return "Allocations"
        }
    }

    var next: CreationStep? {
        CreationStep(rawValue: rawValue + 1)
    }

    var previous: CreationStep? {
        guard rawValue > 0 else { return nil }
        return CreationStep(rawValue: rawValue - 1)
    }

    var isFirst: Bool {
        self == .methodology
    }

    var isLast: Bool {
        self == .allocations
    }
}
