//
//  BudgetPrefiller.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation

/// Stateless service for prefilling new budget periods from previous periods
final class BudgetPrefiller {

    // MARK: - Initialization

    /// Default initializer - class is stateless
    init() {}

    // MARK: - Full Period Prefill

    /// Prefills a new budget period with data from a previous period
    /// - Parameters:
    ///   - previousPeriod: The budget period to copy from
    ///   - previousAllocations: Allocations from the previous period
    ///   - previousTransactions: Transactions from the previous period
    ///   - startDate: Start date for the new period
    ///   - endDate: End date for the new period
    ///   - methodology: Budget methodology for new period (defaults to same as previous)
    /// - Returns: Draft data for creating a new budget period
    func prefillNewBudgetPeriod(
        from previousPeriod: BudgetPeriodDTO,
        allocations previousAllocations: [CategoryAllocationDTO],
        transactions previousTransactions: [TransactionDTO],
        startDate: Date,
        endDate: Date,
        methodology: BudgetMethodology? = nil
    ) -> BudgetPeriodDraft {
        let incomeDrafts = copyIncomes(from: previousPeriod)
        let allocationDrafts = copyAllocations(
            from: previousAllocations,
            transactions: previousTransactions
        )

        return BudgetPeriodDraft(
            methodology: methodology ?? previousPeriod.methodology,
            startDate: startDate,
            endDate: endDate,
            incomeSources: incomeDrafts,
            allocations: allocationDrafts
        )
    }

    // MARK: - Income Copying

    /// Copies income sources from a previous period
    /// - Parameter period: The period to copy income sources from
    /// - Returns: Array of income source drafts
    func copyIncomes(from period: BudgetPeriodDTO) -> [IncomeSourceDraft] {
        period.incomeSources.map { income in
            IncomeSourceDraft(
                sourceName: income.sourceName,
                amount: income.amount,
                originalId: income.id
            )
        }
    }

    /// Copies income sources and allows amount adjustment
    /// - Parameters:
    ///   - period: The period to copy from
    ///   - adjustmentFactor: Multiplier for adjusting amounts (1.0 = no change, 1.1 = 10% increase)
    /// - Returns: Array of income source drafts with adjusted amounts
    func copyIncomesWithAdjustment(
        from period: BudgetPeriodDTO,
        adjustmentFactor: Decimal
    ) -> [IncomeSourceDraft] {
        period.incomeSources.map { income in
            IncomeSourceDraft(
                sourceName: income.sourceName,
                amount: income.amount * adjustmentFactor,
                originalId: income.id
            )
        }
    }

    // MARK: - Allocation Copying

    /// Copies allocations from a previous period with automatic carry-over calculation
    /// - Parameters:
    ///   - allocations: Allocations from the previous period
    ///   - transactions: Transactions from the previous period
    /// - Returns: Array of allocation drafts with carry-over amounts
    func copyAllocations(
        from allocations: [CategoryAllocationDTO],
        transactions: [TransactionDTO]
    ) -> [CategoryAllocationDraft] {
        allocations.compactMap { allocation in
            guard let categoryId = allocation.categoryId else { return nil }

            // Calculate carry over from previous period
            let spent = transactions
                .filter { $0.categoryId == categoryId || $0.subCategoryId == categoryId }
                .reduce(0) { $0 + $1.total }

            let remaining = allocation.totalAvailable - spent
            let carryOver = max(0, remaining) // Only carry over positive amounts

            return CategoryAllocationDraft(
                categoryId: categoryId,
                plannedAmount: allocation.plannedAmount,
                carryOverAmount: carryOver,
                originalAllocationId: allocation.id
            )
        }
    }

    /// Copies allocations without calculating carry-over
    /// - Parameter allocations: Allocations from the previous period
    /// - Returns: Array of allocation drafts with zero carry-over
    func copyAllocationsWithoutCarryOver(
        from allocations: [CategoryAllocationDTO]
    ) -> [CategoryAllocationDraft] {
        allocations.compactMap { allocation in
            guard let categoryId = allocation.categoryId else { return nil }

            return CategoryAllocationDraft(
                categoryId: categoryId,
                plannedAmount: allocation.plannedAmount,
                carryOverAmount: 0,
                originalAllocationId: allocation.id
            )
        }
    }

    /// Copies allocations and allows amount adjustment
    /// - Parameters:
    ///   - allocations: Allocations from the previous period
    ///   - transactions: Transactions from the previous period (for carry-over)
    ///   - adjustmentFactor: Multiplier for adjusting planned amounts
    ///   - includeCarryOver: Whether to calculate and include carry-over
    /// - Returns: Array of allocation drafts with adjusted amounts
    func copyAllocationsWithAdjustment(
        from allocations: [CategoryAllocationDTO],
        transactions: [TransactionDTO],
        adjustmentFactor: Decimal,
        includeCarryOver: Bool = true
    ) -> [CategoryAllocationDraft] {
        allocations.compactMap { allocation in
            guard let categoryId = allocation.categoryId else { return nil }

            let adjustedPlanned = allocation.plannedAmount * adjustmentFactor

            var carryOver: Decimal = 0
            if includeCarryOver {
                let spent = transactions
                    .filter { $0.categoryId == categoryId || $0.subCategoryId == categoryId }
                    .reduce(0) { $0 + $1.total }

                let remaining = allocation.totalAvailable - spent
                carryOver = max(0, remaining)
            }

            return CategoryAllocationDraft(
                categoryId: categoryId,
                plannedAmount: adjustedPlanned,
                carryOverAmount: carryOver,
                originalAllocationId: allocation.id
            )
        }
    }

    // MARK: - Selective Copying

    /// Copies only allocations for specific categories
    /// - Parameters:
    ///   - allocations: All allocations from previous period
    ///   - categoryIds: Categories to include
    ///   - transactions: Transactions for carry-over calculation
    /// - Returns: Array of allocation drafts for selected categories
    func copySelectiveAllocations(
        from allocations: [CategoryAllocationDTO],
        forCategories categoryIds: Set<UUID>,
        transactions: [TransactionDTO]
    ) -> [CategoryAllocationDraft] {
        let filtered = allocations.filter { allocation in
            guard let categoryId = allocation.categoryId else { return false }
            return categoryIds.contains(categoryId)
        }

        return copyAllocations(from: filtered, transactions: transactions)
    }

    // MARK: - Validation

    /// Validates that draft data is ready to create a budget period
    /// - Parameter draft: The budget period draft to validate
    /// - Returns: Validation result with any errors
    func validateDraft(_ draft: BudgetPeriodDraft) -> DraftValidationResult {
        var errors: [String] = []

        // Check date range
        if draft.endDate <= draft.startDate {
            errors.append("End date must be after start date")
        }

        // Check income sources
        if draft.incomeSources.isEmpty {
            errors.append("At least one income source is required")
        }

        for income in draft.incomeSources {
            if income.amount <= 0 {
                errors.append("Income amount must be greater than 0 for '\(income.sourceName)'")
            }
            if income.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append("Income source name cannot be empty")
            }
        }

        // Check allocations
        for allocation in draft.allocations {
            if allocation.plannedAmount < 0 {
                errors.append("Planned amount cannot be negative")
            }
            if allocation.carryOverAmount < 0 {
                errors.append("Carry over amount cannot be negative")
            }
        }

        return DraftValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }

    // MARK: - Summary Calculations

    /// Calculates summary statistics for a draft budget period
    /// - Parameter draft: The budget period draft
    /// - Returns: Summary with totals and percentages
    func calculateDraftSummary(_ draft: BudgetPeriodDraft) -> BudgetDraftSummary {
        let totalIncome = draft.incomeSources.reduce(0) { $0 + $1.amount }
        let totalPlanned = draft.allocations.reduce(0) { $0 + $1.plannedAmount }
        let totalCarryOver = draft.allocations.reduce(0) { $0 + $1.carryOverAmount }
        let totalAvailable = totalPlanned + totalCarryOver

        let allocatedPercentage: Decimal = totalIncome > 0 ? (totalPlanned / totalIncome) * 100 : 0
        let remainingToAllocate = totalIncome - totalPlanned

        return BudgetDraftSummary(
            totalIncome: totalIncome,
            totalPlanned: totalPlanned,
            totalCarryOver: totalCarryOver,
            totalAvailable: totalAvailable,
            allocatedPercentage: allocatedPercentage,
            remainingToAllocate: remainingToAllocate
        )
    }
}

// MARK: - Supporting Types

/// Draft data for creating a new budget period
struct BudgetPeriodDraft: Equatable {
    let methodology: BudgetMethodology
    let startDate: Date
    let endDate: Date
    let incomeSources: [IncomeSourceDraft]
    let allocations: [CategoryAllocationDraft]
}

/// Draft data for an income source
struct IncomeSourceDraft: Equatable {
    let sourceName: String
    let amount: Decimal
    let originalId: UUID?

    init(sourceName: String, amount: Decimal, originalId: UUID? = nil) {
        self.sourceName = sourceName
        self.amount = amount
        self.originalId = originalId
    }
}

/// Draft data for a category allocation
struct CategoryAllocationDraft: Equatable {
    let categoryId: UUID
    let plannedAmount: Decimal
    let carryOverAmount: Decimal
    let originalAllocationId: UUID?

    init(
        categoryId: UUID,
        plannedAmount: Decimal,
        carryOverAmount: Decimal = 0,
        originalAllocationId: UUID? = nil
    ) {
        self.categoryId = categoryId
        self.plannedAmount = plannedAmount
        self.carryOverAmount = carryOverAmount
        self.originalAllocationId = originalAllocationId
    }

    var totalAvailable: Decimal {
        plannedAmount + carryOverAmount
    }
}

/// Result of validating a budget period draft
struct DraftValidationResult: Equatable {
    let isValid: Bool
    let errors: [String]
}

/// Summary statistics for a budget period draft
struct BudgetDraftSummary: Equatable {
    let totalIncome: Decimal
    let totalPlanned: Decimal
    let totalCarryOver: Decimal
    let totalAvailable: Decimal
    let allocatedPercentage: Decimal
    let remainingToAllocate: Decimal

    var isFullyAllocated: Bool {
        remainingToAllocate == 0
    }

    var isOverAllocated: Bool {
        remainingToAllocate < 0
    }
}
