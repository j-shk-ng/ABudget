//
//  BudgetCalculator.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation

/// Stateless calculator for budget-related calculations
final class BudgetCalculator {

    // MARK: - Initialization

    /// Default initializer - class is stateless
    init() {}

    // MARK: - Spent Amount Calculations

    /// Calculates the total spent amount for a specific category in a budget period
    /// - Parameters:
    ///   - categoryId: The UUID of the category
    ///   - transactions: Array of transactions to analyze
    /// - Returns: Total spent amount for the category
    func calculateSpentAmount(
        forCategoryId categoryId: UUID,
        in transactions: [TransactionDTO]
    ) -> Decimal {
        transactions
            .filter { $0.categoryId == categoryId || $0.subCategoryId == categoryId }
            .reduce(0) { $0 + $1.total }
    }

    /// Calculates the total spent amount for all transactions in a period
    /// - Parameter transactions: Array of transactions
    /// - Returns: Total spent amount
    func calculateTotalSpent(in transactions: [TransactionDTO]) -> Decimal {
        transactions.reduce(0) { $0 + $1.total }
    }

    /// Calculates spent amount by bucket type
    /// - Parameters:
    ///   - bucket: The bucket type to calculate for
    ///   - transactions: Array of transactions to analyze
    /// - Returns: Total spent amount for the bucket
    func calculateSpentAmount(
        forBucket bucket: BucketType,
        in transactions: [TransactionDTO]
    ) -> Decimal {
        transactions
            .filter { $0.bucket == bucket }
            .reduce(0) { $0 + $1.total }
    }

    // MARK: - Remaining Amount Calculations

    /// Calculates remaining budget amount
    /// - Parameters:
    ///   - planned: The planned/allocated amount
    ///   - spent: The amount already spent
    /// - Returns: Remaining amount (can be negative if over budget)
    func calculateRemainingAmount(planned: Decimal, spent: Decimal) -> Decimal {
        planned - spent
    }

    /// Calculates remaining amount for a category allocation
    /// - Parameters:
    ///   - allocation: The category allocation
    ///   - spent: The amount spent on this category
    /// - Returns: Remaining amount including carry over
    func calculateRemainingAmount(
        forAllocation allocation: CategoryAllocationDTO,
        spent: Decimal
    ) -> Decimal {
        allocation.totalAvailable - spent
    }

    // MARK: - Carry Over Calculations

    /// Calculates carry over amount from a previous period for a specific category
    /// - Parameters:
    ///   - categoryId: The category to calculate carry over for
    ///   - previousAllocation: The allocation from the previous period
    ///   - previousTransactions: Transactions from the previous period
    /// - Returns: Carry over amount (positive if under budget, zero if over budget)
    func calculateCarryOver(
        forCategoryId categoryId: UUID,
        previousAllocation: CategoryAllocationDTO?,
        previousTransactions: [TransactionDTO]
    ) -> Decimal {
        guard let allocation = previousAllocation else { return 0 }

        let spent = calculateSpentAmount(forCategoryId: categoryId, in: previousTransactions)
        let remaining = calculateRemainingAmount(forAllocation: allocation, spent: spent)

        // Only carry over positive amounts (unspent budget)
        return max(0, remaining)
    }

    /// Calculates carry over amounts for all categories from a previous period
    /// - Parameters:
    ///   - previousAllocations: All allocations from the previous period
    ///   - previousTransactions: All transactions from the previous period
    /// - Returns: Dictionary mapping category IDs to carry over amounts
    func calculateAllCarryOvers(
        from previousAllocations: [CategoryAllocationDTO],
        previousTransactions: [TransactionDTO]
    ) -> [UUID: Decimal] {
        var carryOvers: [UUID: Decimal] = [:]

        for allocation in previousAllocations {
            guard let categoryId = allocation.categoryId else { continue }

            let carryOver = calculateCarryOver(
                forCategoryId: categoryId,
                previousAllocation: allocation,
                previousTransactions: previousTransactions
            )

            if carryOver > 0 {
                carryOvers[categoryId] = carryOver
            }
        }

        return carryOvers
    }

    // MARK: - Budget Period Totals

    /// Calculates comprehensive totals for a budget period
    /// - Parameters:
    ///   - period: The budget period
    ///   - allocations: All allocations for the period
    ///   - transactions: All transactions for the period
    /// - Returns: Budget period totals including income, planned, spent, and remaining
    func calculateBudgetPeriodTotals(
        period: BudgetPeriodDTO,
        allocations: [CategoryAllocationDTO],
        transactions: [TransactionDTO]
    ) -> BudgetPeriodTotals {
        let totalIncome = period.totalIncome
        let totalPlanned = allocations.totalPlanned
        let totalSpent = calculateTotalSpent(in: transactions)
        let totalRemaining = calculateRemainingAmount(planned: totalPlanned, spent: totalSpent)

        return BudgetPeriodTotals(
            totalIncome: totalIncome,
            totalPlanned: totalPlanned,
            totalSpent: totalSpent,
            totalRemaining: totalRemaining
        )
    }

    // MARK: - Budget Health Calculations

    /// Calculates what percentage of the allocated budget has been spent
    /// - Parameters:
    ///   - planned: The planned amount
    ///   - spent: The spent amount
    /// - Returns: Percentage spent (0-100+)
    func calculateBudgetUtilization(planned: Decimal, spent: Decimal) -> Decimal {
        guard planned > 0 else { return 0 }
        return (spent / planned) * 100
    }

    /// Determines if a category is over budget
    /// - Parameters:
    ///   - allocation: The category allocation
    ///   - spent: Amount spent on the category
    /// - Returns: True if spending exceeds total available (planned + carry over)
    func isOverBudget(allocation: CategoryAllocationDTO, spent: Decimal) -> Bool {
        spent > allocation.totalAvailable
    }

    /// Calculates the over-budget amount
    /// - Parameters:
    ///   - allocation: The category allocation
    ///   - spent: Amount spent on the category
    /// - Returns: Amount over budget (zero if not over budget)
    func calculateOverBudgetAmount(allocation: CategoryAllocationDTO, spent: Decimal) -> Decimal {
        let remaining = calculateRemainingAmount(forAllocation: allocation, spent: spent)
        return remaining < 0 ? abs(remaining) : 0
    }

    // MARK: - Projection Calculations

    /// Projects end-of-period spending based on current rate
    /// - Parameters:
    ///   - currentSpent: Amount spent so far
    ///   - period: The budget period
    ///   - asOfDate: The current date (defaults to now)
    /// - Returns: Projected total spending by end of period
    func projectEndOfPeriodSpending(
        currentSpent: Decimal,
        period: BudgetPeriodDTO,
        asOfDate: Date = Date()
    ) -> Decimal {
        // Calculate days elapsed and total days
        let totalDays = period.durationInDays
        guard totalDays > 0 else { return currentSpent }

        let daysElapsed = Calendar.current.dateComponents(
            [.day],
            from: period.startDate,
            to: min(asOfDate, period.endDate)
        ).day ?? 0

        guard daysElapsed > 0 else { return currentSpent }

        // Calculate daily spending rate
        let dailyRate = currentSpent / Decimal(daysElapsed)

        // Project for remaining days
        return dailyRate * Decimal(totalDays)
    }

    /// Calculates suggested daily spending limit to stay on budget
    /// - Parameters:
    ///   - allocation: The category allocation
    ///   - spent: Amount already spent
    ///   - period: The budget period
    ///   - asOfDate: The current date (defaults to now)
    /// - Returns: Suggested daily spending limit
    func calculateDailySpendingLimit(
        allocation: CategoryAllocationDTO,
        spent: Decimal,
        period: BudgetPeriodDTO,
        asOfDate: Date = Date()
    ) -> Decimal {
        let remaining = calculateRemainingAmount(forAllocation: allocation, spent: spent)
        guard remaining > 0 else { return 0 }

        let daysRemaining = Calendar.current.dateComponents(
            [.day],
            from: min(asOfDate, period.endDate),
            to: period.endDate
        ).day ?? 0

        guard daysRemaining > 0 else { return remaining }

        return remaining / Decimal(daysRemaining)
    }
}
