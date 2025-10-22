//
//  TransactionAssigner.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation

/// Stateless service for assigning transactions to budget periods
final class TransactionAssigner {

    // MARK: - Initialization

    /// Default initializer - class is stateless
    init() {}

    // MARK: - Transaction Assignment

    /// Assigns a transaction to the appropriate budget period based on transaction date
    /// - Parameters:
    ///   - transaction: The transaction to assign
    ///   - periods: Available budget periods to assign to
    /// - Returns: The budget period that contains the transaction date, or nil if none found
    func assignTransactionToBudgetPeriod(
        transaction: TransactionDTO,
        periods: [BudgetPeriodDTO]
    ) -> BudgetPeriodDTO? {
        // Find period that contains the transaction date
        periods.first { period in
            period.contains(transaction.date)
        }
    }

    /// Assigns multiple transactions to their appropriate budget periods
    /// - Parameters:
    ///   - transactions: Array of transactions to assign
    ///   - periods: Available budget periods
    /// - Returns: Dictionary mapping budget period IDs to their assigned transactions
    func assignTransactionsToBudgetPeriods(
        transactions: [TransactionDTO],
        periods: [BudgetPeriodDTO]
    ) -> [UUID: [TransactionDTO]] {
        var assignments: [UUID: [TransactionDTO]] = [:]

        for transaction in transactions {
            if let period = assignTransactionToBudgetPeriod(transaction: transaction, periods: periods) {
                assignments[period.id, default: []].append(transaction)
            }
        }

        return assignments
    }

    // MARK: - Orphaned Transaction Handling

    /// Identifies transactions that don't belong to any budget period
    /// - Parameters:
    ///   - transactions: All transactions to check
    ///   - periods: Available budget periods
    /// - Returns: Array of transactions that don't fall within any period
    func findOrphanedTransactions(
        transactions: [TransactionDTO],
        periods: [BudgetPeriodDTO]
    ) -> [TransactionDTO] {
        transactions.filter { transaction in
            assignTransactionToBudgetPeriod(transaction: transaction, periods: periods) == nil
        }
    }

    /// Checks if a transaction is orphaned (not assigned to any period)
    /// - Parameters:
    ///   - transaction: The transaction to check
    ///   - periods: Available budget periods
    /// - Returns: True if transaction doesn't belong to any period
    func isOrphaned(
        transaction: TransactionDTO,
        periods: [BudgetPeriodDTO]
    ) -> Bool {
        assignTransactionToBudgetPeriod(transaction: transaction, periods: periods) == nil
    }

    /// Gets the status of transaction assignment
    /// - Parameters:
    ///   - transaction: The transaction to check
    ///   - periods: Available budget periods
    /// - Returns: Assignment status
    func getAssignmentStatus(
        transaction: TransactionDTO,
        periods: [BudgetPeriodDTO]
    ) -> TransactionAssignmentStatus {
        if let period = assignTransactionToBudgetPeriod(transaction: transaction, periods: periods) {
            return .assigned(periodId: period.id, periodName: formatPeriodName(period))
        } else {
            return .orphaned(reason: determineOrphanReason(transaction: transaction, periods: periods))
        }
    }

    // MARK: - Reassignment on Period Change

    /// Reassigns all transactions when budget periods are modified
    /// - Parameters:
    ///   - transactions: All transactions to reassign
    ///   - updatedPeriods: The updated list of budget periods
    /// - Returns: Result containing successfully assigned and orphaned transactions
    func reassignTransactionsOnPeriodChange(
        transactions: [TransactionDTO],
        updatedPeriods: [BudgetPeriodDTO]
    ) -> ReassignmentResult {
        var assigned: [UUID: [TransactionDTO]] = [:]
        var orphaned: [TransactionDTO] = []

        for transaction in transactions {
            if let period = assignTransactionToBudgetPeriod(transaction: transaction, periods: updatedPeriods) {
                assigned[period.id, default: []].append(transaction)
            } else {
                orphaned.append(transaction)
            }
        }

        return ReassignmentResult(
            assignedTransactions: assigned,
            orphanedTransactions: orphaned,
            totalProcessed: transactions.count
        )
    }

    /// Suggests a budget period for an orphaned transaction
    /// - Parameters:
    ///   - transaction: The orphaned transaction
    ///   - periods: Available budget periods
    /// - Returns: Suggested period (closest by date) or nil if no periods exist
    func suggestPeriodForOrphanedTransaction(
        transaction: TransactionDTO,
        periods: [BudgetPeriodDTO]
    ) -> BudgetPeriodDTO? {
        guard !periods.isEmpty else { return nil }

        // Find period with closest start date
        return periods.min { period1, period2 in
            let diff1 = abs(period1.startDate.timeIntervalSince(transaction.date))
            let diff2 = abs(period2.startDate.timeIntervalSince(transaction.date))
            return diff1 < diff2
        }
    }

    // MARK: - Period Overlap Detection

    /// Checks if a transaction could belong to multiple overlapping periods
    /// - Parameters:
    ///   - transaction: The transaction to check
    ///   - periods: Budget periods to check for overlaps
    /// - Returns: Array of periods that contain the transaction date
    func findOverlappingPeriods(
        transaction: TransactionDTO,
        periods: [BudgetPeriodDTO]
    ) -> [BudgetPeriodDTO] {
        periods.filter { $0.contains(transaction.date) }
    }

    /// Detects if there are any overlapping periods in the list
    /// - Parameter periods: Budget periods to check
    /// - Returns: True if any periods overlap
    func hasOverlappingPeriods(periods: [BudgetPeriodDTO]) -> Bool {
        for i in 0..<periods.count {
            for j in (i + 1)..<periods.count {
                let period1 = periods[i]
                let period2 = periods[j]

                // Periods overlap if: start1 <= end2 AND end1 >= start2
                if period1.startDate <= period2.endDate && period1.endDate >= period2.startDate {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Private Helpers

    private func formatPeriodName(_ period: BudgetPeriodDTO) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: period.startDate)) - \(formatter.string(from: period.endDate))"
    }

    private func determineOrphanReason(
        transaction: TransactionDTO,
        periods: [BudgetPeriodDTO]
    ) -> String {
        if periods.isEmpty {
            return "No budget periods exist"
        }

        // Check if transaction is before all periods
        if let earliestPeriod = periods.min(by: { $0.startDate < $1.startDate }),
           transaction.date < earliestPeriod.startDate {
            return "Transaction date is before earliest budget period"
        }

        // Check if transaction is after all periods
        if let latestPeriod = periods.max(by: { $0.endDate < $1.endDate }),
           transaction.date > latestPeriod.endDate {
            return "Transaction date is after latest budget period"
        }

        // Transaction falls in a gap between periods
        return "Transaction date falls in a gap between budget periods"
    }
}

// MARK: - Supporting Types

/// Status of a transaction's assignment to a budget period
enum TransactionAssignmentStatus: Equatable {
    /// Transaction is assigned to a budget period
    case assigned(periodId: UUID, periodName: String)

    /// Transaction is not assigned to any period
    case orphaned(reason: String)

    var isAssigned: Bool {
        if case .assigned = self {
            return true
        }
        return false
    }

    var isOrphaned: Bool {
        !isAssigned
    }
}

/// Result of reassigning transactions after period changes
struct ReassignmentResult: Equatable {
    /// Transactions successfully assigned to periods
    let assignedTransactions: [UUID: [TransactionDTO]]

    /// Transactions that couldn't be assigned
    let orphanedTransactions: [TransactionDTO]

    /// Total number of transactions processed
    let totalProcessed: Int

    /// Number of successfully assigned transactions
    var assignedCount: Int {
        assignedTransactions.values.reduce(0) { $0 + $1.count }
    }

    /// Number of orphaned transactions
    var orphanedCount: Int {
        orphanedTransactions.count
    }

    /// Percentage of transactions successfully assigned
    var successRate: Decimal {
        guard totalProcessed > 0 else { return 0 }
        return (Decimal(assignedCount) / Decimal(totalProcessed)) * 100
    }
}
