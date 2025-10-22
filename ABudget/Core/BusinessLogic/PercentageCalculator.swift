//
//  PercentageCalculator.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation

/// Stateless calculator for percentage-based budget calculations
final class PercentageCalculator {

    // MARK: - Initialization

    /// Default initializer - class is stateless
    init() {}

    // MARK: - Constants

    /// Acceptable variance from target percentage (±5%)
    private static let acceptableVariance: Decimal = 5.0

    // MARK: - Bucket Spending Calculations

    /// Calculates total spending for a specific bucket type
    /// - Parameters:
    ///   - bucket: The bucket type to calculate
    ///   - transactions: Array of transactions to analyze
    /// - Returns: Total amount spent in the bucket
    func calculateBucketSpending(
        bucket: BucketType,
        transactions: [TransactionDTO]
    ) -> Decimal {
        transactions
            .filter { $0.bucket == bucket }
            .reduce(0) { $0 + $1.total }
    }

    /// Calculates spending for all buckets
    /// - Parameter transactions: Array of transactions to analyze
    /// - Returns: Dictionary mapping bucket types to their spending amounts
    func calculateAllBucketSpending(
        transactions: [TransactionDTO]
    ) -> [BucketType: Decimal] {
        var spending: [BucketType: Decimal] = [
            .needs: 0,
            .wants: 0,
            .savings: 0
        ]

        for transaction in transactions {
            spending[transaction.bucket, default: 0] += transaction.total
        }

        return spending
    }

    // MARK: - Actual Percentage Calculations

    /// Calculates the actual percentage of income spent on a bucket
    /// - Parameters:
    ///   - bucket: The bucket type
    ///   - transactions: Transactions to analyze
    ///   - totalIncome: Total income for the period
    /// - Returns: Percentage of income spent on the bucket (0-100+)
    func calculateActualPercentage(
        bucket: BucketType,
        transactions: [TransactionDTO],
        totalIncome: Decimal
    ) -> Decimal {
        guard totalIncome > 0 else { return 0 }

        let spending = calculateBucketSpending(bucket: bucket, transactions: transactions)
        return (spending / totalIncome) * 100
    }

    /// Calculates actual percentages for all buckets
    /// - Parameters:
    ///   - transactions: Transactions to analyze
    ///   - totalIncome: Total income for the period
    /// - Returns: Dictionary mapping bucket types to their actual percentages
    func calculateAllActualPercentages(
        transactions: [TransactionDTO],
        totalIncome: Decimal
    ) -> [BucketType: Decimal] {
        guard totalIncome > 0 else {
            return [.needs: 0, .wants: 0, .savings: 0]
        }

        let spending = calculateAllBucketSpending(transactions: transactions)

        return [
            .needs: (spending[.needs, default: 0] / totalIncome) * 100,
            .wants: (spending[.wants, default: 0] / totalIncome) * 100,
            .savings: (spending[.savings, default: 0] / totalIncome) * 100
        ]
    }

    // MARK: - Comparison to Target

    /// Compares actual spending percentage to target percentage
    /// - Parameters:
    ///   - actual: The actual percentage spent
    ///   - target: The target percentage from settings
    /// - Returns: Comparison result indicating if on track, under, or over target
    func compareToTarget(actual: Decimal, target: Decimal) -> PercentageComparison {
        let difference = actual - target

        if abs(difference) <= Self.acceptableVariance {
            return .onTrack(difference: difference)
        } else if difference < 0 {
            return .underTarget(difference: difference)
        } else {
            return .overTarget(difference: difference)
        }
    }

    /// Compares all bucket spending to targets from settings
    /// - Parameters:
    ///   - transactions: Transactions to analyze
    ///   - totalIncome: Total income for the period
    ///   - settings: User settings containing target percentages
    /// - Returns: Dictionary mapping bucket types to their comparison results
    func compareAllToTargets(
        transactions: [TransactionDTO],
        totalIncome: Decimal,
        settings: UserSettingsDTO
    ) -> [BucketType: PercentageComparison] {
        let actualPercentages = calculateAllActualPercentages(
            transactions: transactions,
            totalIncome: totalIncome
        )

        return [
            .needs: compareToTarget(
                actual: actualPercentages[.needs, default: 0],
                target: settings.needsPercentage
            ),
            .wants: compareToTarget(
                actual: actualPercentages[.wants, default: 0],
                target: settings.wantsPercentage
            ),
            .savings: compareToTarget(
                actual: actualPercentages[.savings, default: 0],
                target: settings.savingsPercentage
            )
        ]
    }

    // MARK: - Percentage Validation

    /// Validates that percentages sum to 100 and are all non-negative
    /// - Parameters:
    ///   - needs: Needs percentage
    ///   - wants: Wants percentage
    ///   - savings: Savings percentage
    /// - Returns: True if valid (sum equals 100 and all non-negative)
    func validatePercentageAllocation(
        needs: Decimal,
        wants: Decimal,
        savings: Decimal
    ) -> Bool {
        // Check non-negative
        guard needs >= 0, wants >= 0, savings >= 0 else {
            return false
        }

        // Check sum equals 100
        let sum = needs + wants + savings
        return sum == 100
    }

    /// Validates UserSettings percentages
    /// - Parameter settings: The settings to validate
    /// - Returns: True if percentages are valid
    func validatePercentageAllocation(settings: UserSettingsDTO) -> Bool {
        validatePercentageAllocation(
            needs: settings.needsPercentage,
            wants: settings.wantsPercentage,
            savings: settings.savingsPercentage
        )
    }

    // MARK: - Target Amount Calculations

    /// Calculates target spending amount for a bucket based on percentage
    /// - Parameters:
    ///   - bucket: The bucket type
    ///   - totalIncome: Total income for the period
    ///   - settings: User settings containing target percentages
    /// - Returns: Target amount to spend on the bucket
    func calculateTargetAmount(
        forBucket bucket: BucketType,
        totalIncome: Decimal,
        settings: UserSettingsDTO
    ) -> Decimal {
        let percentage: Decimal
        switch bucket {
        case .needs:
            percentage = settings.needsPercentage
        case .wants:
            percentage = settings.wantsPercentage
        case .savings:
            percentage = settings.savingsPercentage
        }

        return (totalIncome * percentage) / 100
    }

    /// Calculates target amounts for all buckets
    /// - Parameters:
    ///   - totalIncome: Total income for the period
    ///   - settings: User settings containing target percentages
    /// - Returns: Dictionary mapping bucket types to their target amounts
    func calculateAllTargetAmounts(
        totalIncome: Decimal,
        settings: UserSettingsDTO
    ) -> [BucketType: Decimal] {
        [
            .needs: calculateTargetAmount(forBucket: .needs, totalIncome: totalIncome, settings: settings),
            .wants: calculateTargetAmount(forBucket: .wants, totalIncome: totalIncome, settings: settings),
            .savings: calculateTargetAmount(forBucket: .savings, totalIncome: totalIncome, settings: settings)
        ]
    }

    // MARK: - Variance Calculations

    /// Calculates the variance between actual and target spending
    /// - Parameters:
    ///   - bucket: The bucket type
    ///   - transactions: Transactions to analyze
    ///   - totalIncome: Total income for the period
    ///   - settings: User settings containing target percentages
    /// - Returns: Variance amount (positive means over target, negative means under)
    func calculateVariance(
        forBucket bucket: BucketType,
        transactions: [TransactionDTO],
        totalIncome: Decimal,
        settings: UserSettingsDTO
    ) -> Decimal {
        let actual = calculateBucketSpending(bucket: bucket, transactions: transactions)
        let target = calculateTargetAmount(forBucket: bucket, totalIncome: totalIncome, settings: settings)

        return actual - target
    }

    /// Calculates variance for all buckets
    /// - Parameters:
    ///   - transactions: Transactions to analyze
    ///   - totalIncome: Total income for the period
    ///   - settings: User settings containing target percentages
    /// - Returns: Dictionary mapping bucket types to their variance amounts
    func calculateAllVariances(
        transactions: [TransactionDTO],
        totalIncome: Decimal,
        settings: UserSettingsDTO
    ) -> [BucketType: Decimal] {
        [
            .needs: calculateVariance(forBucket: .needs, transactions: transactions, totalIncome: totalIncome, settings: settings),
            .wants: calculateVariance(forBucket: .wants, transactions: transactions, totalIncome: totalIncome, settings: settings),
            .savings: calculateVariance(forBucket: .savings, transactions: transactions, totalIncome: totalIncome, settings: settings)
        ]
    }

    // MARK: - Remaining Budget Calculations

    /// Calculates remaining budget for a bucket to stay on target
    /// - Parameters:
    ///   - bucket: The bucket type
    ///   - transactions: Transactions to analyze
    ///   - totalIncome: Total income for the period
    ///   - settings: User settings containing target percentages
    /// - Returns: Remaining amount that can be spent to reach target (can be negative)
    func calculateRemainingBudget(
        forBucket bucket: BucketType,
        transactions: [TransactionDTO],
        totalIncome: Decimal,
        settings: UserSettingsDTO
    ) -> Decimal {
        let target = calculateTargetAmount(forBucket: bucket, totalIncome: totalIncome, settings: settings)
        let spent = calculateBucketSpending(bucket: bucket, transactions: transactions)

        return target - spent
    }

    // MARK: - Edge Case Handling

    /// Safely calculates percentage handling zero income
    /// - Parameters:
    ///   - amount: The amount spent
    ///   - totalIncome: Total income (may be zero)
    /// - Returns: Percentage (returns 0 if income is zero)
    func safeCalculatePercentage(amount: Decimal, totalIncome: Decimal) -> Decimal {
        guard totalIncome > 0 else { return 0 }
        return (amount / totalIncome) * 100
    }
}
