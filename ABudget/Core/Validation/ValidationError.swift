//
//  ValidationError.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation

/// Custom error type for validation failures
enum ValidationError: LocalizedError {
    // Transaction validation errors
    case transactionAmountInvalid(String)
    case transactionMerchantRequired
    case transactionDateInvalid(String)
    case transactionBucketInvalid

    // Budget period validation errors
    case budgetPeriodDateInvalid(String)
    case budgetPeriodNoIncome
    case budgetPeriodOverlap(Date, Date)

    // Category allocation validation errors
    case allocationAmountInvalid(String)
    case allocationCategoryRequired
    case allocationBudgetPeriodRequired

    // User settings validation errors
    case percentageInvalid(String)
    case percentageSumInvalid(Decimal)
    case percentageNegative(String)

    // General validation errors
    case requiredFieldMissing(String)
    case invalidDateRange(String)

    var errorDescription: String? {
        switch self {
        // Transaction errors
        case .transactionAmountInvalid(let reason):
            return "Transaction amount is invalid: \(reason)"
        case .transactionMerchantRequired:
            return "Transaction merchant is required"
        case .transactionDateInvalid(let reason):
            return "Transaction date is invalid: \(reason)"
        case .transactionBucketInvalid:
            return "Transaction bucket type is invalid"

        // Budget period errors
        case .budgetPeriodDateInvalid(let reason):
            return "Budget period dates are invalid: \(reason)"
        case .budgetPeriodNoIncome:
            return "Budget period must have at least one income source"
        case .budgetPeriodOverlap(let start, let end):
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "Budget period overlaps with existing period (\(formatter.string(from: start)) - \(formatter.string(from: end)))"

        // Category allocation errors
        case .allocationAmountInvalid(let reason):
            return "Allocation amount is invalid: \(reason)"
        case .allocationCategoryRequired:
            return "Allocation must have a category assigned"
        case .allocationBudgetPeriodRequired:
            return "Allocation must be assigned to a budget period"

        // User settings errors
        case .percentageInvalid(let field):
            return "Percentage for '\(field)' is invalid"
        case .percentageSumInvalid(let sum):
            return "Percentages must sum to 100, but sum to \(sum)"
        case .percentageNegative(let field):
            return "Percentage for '\(field)' cannot be negative"

        // General errors
        case .requiredFieldMissing(let field):
            return "Required field '\(field)' is missing"
        case .invalidDateRange(let reason):
            return "Invalid date range: \(reason)"
        }
    }
}
