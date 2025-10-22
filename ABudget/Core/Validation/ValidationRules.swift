//
//  ValidationRules.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation

/// Centralized validation rules for all data models
struct ValidationRules {

    // MARK: - Transaction Validation

    /// Validates a transaction
    /// - Parameter transaction: The transaction to validate
    /// - Throws: ValidationError if validation fails
    static func validateTransaction(_ transaction: TransactionDTO) throws {
        // Validate amount is positive
        if transaction.subTotal <= 0 {
            throw ValidationError.transactionAmountInvalid("Subtotal must be greater than 0")
        }

        // Validate tax is non-negative if present
        if let tax = transaction.tax, tax < 0 {
            throw ValidationError.transactionAmountInvalid("Tax cannot be negative")
        }

        // Validate merchant is not empty
        if transaction.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.transactionMerchantRequired
        }

        // Validate date is not in the future
        if transaction.date > Date() {
            throw ValidationError.transactionDateInvalid("Transaction date cannot be in the future")
        }
    }

    /// Validates a transaction with additional business rules (category required)
    /// - Parameter transaction: The transaction to validate
    /// - Throws: ValidationError if validation fails
    static func validateTransactionStrict(_ transaction: TransactionDTO) throws {
        // First run basic validation
        try validateTransaction(transaction)

        // Require category for strict validation
        if transaction.categoryId == nil {
            throw ValidationError.requiredFieldMissing("category")
        }
    }

    // MARK: - Budget Period Validation

    /// Validates a budget period
    /// - Parameter period: The budget period to validate
    /// - Throws: ValidationError if validation fails
    static func validateBudgetPeriod(_ period: BudgetPeriodDTO) throws {
        // Validate end date is after start date
        if period.endDate <= period.startDate {
            throw ValidationError.budgetPeriodDateInvalid("End date must be after start date")
        }

        // Validate period has at least one income source
        if period.incomeSources.isEmpty {
            throw ValidationError.budgetPeriodNoIncome
        }

        // Validate all income sources have positive amounts
        for income in period.incomeSources {
            if income.amount <= 0 {
                throw ValidationError.transactionAmountInvalid("Income amount must be greater than 0 for '\(income.sourceName)'")
            }
        }

        // Validate income source names are not empty
        for income in period.incomeSources {
            if income.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ValidationError.requiredFieldMissing("income source name")
            }
        }
    }

    /// Validates that a budget period doesn't overlap with existing periods
    /// - Parameters:
    ///   - period: The budget period to validate
    ///   - existingPeriods: Array of existing budget periods
    /// - Throws: ValidationError if there's an overlap
    static func validateBudgetPeriodNoOverlap(
        _ period: BudgetPeriodDTO,
        against existingPeriods: [BudgetPeriodDTO]
    ) throws {
        for existing in existingPeriods {
            // Skip comparing with itself (for updates)
            if existing.id == period.id {
                continue
            }

            // Check for overlap: periods overlap if start1 <= end2 AND end1 >= start2
            if period.startDate <= existing.endDate && period.endDate >= existing.startDate {
                throw ValidationError.budgetPeriodOverlap(existing.startDate, existing.endDate)
            }
        }
    }

    // MARK: - Category Allocation Validation

    /// Validates a category allocation
    /// - Parameter allocation: The category allocation to validate
    /// - Throws: ValidationError if validation fails
    static func validateCategoryAllocation(_ allocation: CategoryAllocationDTO) throws {
        // Validate planned amount is non-negative
        if allocation.plannedAmount < 0 {
            throw ValidationError.allocationAmountInvalid("Planned amount cannot be negative")
        }

        // Validate carry over amount is non-negative
        if allocation.carryOverAmount < 0 {
            throw ValidationError.allocationAmountInvalid("Carry over amount cannot be negative")
        }

        // Validate category is assigned
        if allocation.categoryId == nil {
            throw ValidationError.allocationCategoryRequired
        }

        // Validate budget period is assigned
        if allocation.budgetPeriodId == nil {
            throw ValidationError.allocationBudgetPeriodRequired
        }
    }

    // MARK: - User Settings Validation

    /// Validates user settings percentages
    /// - Parameter settings: The user settings to validate
    /// - Throws: ValidationError if validation fails
    static func validatePercentages(_ settings: UserSettingsDTO) throws {
        // Validate all percentages are non-negative
        if settings.needsPercentage < 0 {
            throw ValidationError.percentageNegative("needs")
        }
        if settings.wantsPercentage < 0 {
            throw ValidationError.percentageNegative("wants")
        }
        if settings.savingsPercentage < 0 {
            throw ValidationError.percentageNegative("savings")
        }

        // Validate percentages sum to 100
        let sum = settings.totalPercentage
        if sum != 100 {
            throw ValidationError.percentageSumInvalid(sum)
        }
    }

    // MARK: - Income Source Validation

    /// Validates an income source
    /// - Parameter income: The income source to validate
    /// - Throws: ValidationError if validation fails
    static func validateIncomeSource(_ income: IncomeSourceDTO) throws {
        // Validate amount is positive
        if income.amount <= 0 {
            throw ValidationError.transactionAmountInvalid("Income amount must be greater than 0")
        }

        // Validate source name is not empty
        if income.sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.requiredFieldMissing("income source name")
        }
    }

    // MARK: - General Validation Helpers

    /// Validates that a decimal value is within a range
    /// - Parameters:
    ///   - value: The value to validate
    ///   - min: Minimum allowed value (inclusive)
    ///   - max: Maximum allowed value (inclusive)
    ///   - fieldName: Name of the field for error messages
    /// - Throws: ValidationError if value is out of range
    static func validateDecimalRange(
        _ value: Decimal,
        min: Decimal,
        max: Decimal,
        fieldName: String
    ) throws {
        if value < min || value > max {
            throw ValidationError.transactionAmountInvalid("\(fieldName) must be between \(min) and \(max)")
        }
    }

    /// Validates that a date range is valid
    /// - Parameters:
    ///   - startDate: The start date
    ///   - endDate: The end date
    /// - Throws: ValidationError if date range is invalid
    static func validateDateRange(startDate: Date, endDate: Date) throws {
        if endDate <= startDate {
            throw ValidationError.invalidDateRange("End date must be after start date")
        }
    }

    /// Validates that a string is not empty
    /// - Parameters:
    ///   - value: The string to validate
    ///   - fieldName: Name of the field for error messages
    /// - Throws: ValidationError if string is empty
    static func validateNotEmpty(_ value: String, fieldName: String) throws {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ValidationError.requiredFieldMissing(fieldName)
        }
    }
}
