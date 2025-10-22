//
//  PercentageComparison.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation

/// Represents the comparison between actual and target percentages
enum PercentageComparison: Equatable {
    /// Actual spending is within acceptable range of target (±5%)
    case onTrack(difference: Decimal)

    /// Actual spending is below target (good for needs/wants, bad for savings)
    case underTarget(difference: Decimal)

    /// Actual spending is above target (bad for needs/wants, could be good for savings)
    case overTarget(difference: Decimal)

    /// The difference from target as a positive number
    var absoluteDifference: Decimal {
        switch self {
        case .onTrack(let diff), .underTarget(let diff), .overTarget(let diff):
            return abs(diff)
        }
    }

    /// Whether the current state is considered acceptable
    var isAcceptable: Bool {
        switch self {
        case .onTrack:
            return true
        case .underTarget, .overTarget:
            return false
        }
    }

    /// User-friendly description of the comparison
    var description: String {
        switch self {
        case .onTrack(let diff):
            return "On track (\(diff > 0 ? "+" : "")\(diff)%)"
        case .underTarget(let diff):
            return "Under target by \(abs(diff))%"
        case .overTarget(let diff):
            return "Over target by \(abs(diff))%"
        }
    }
}

/// Result of budget period totals calculation
struct BudgetPeriodTotals: Equatable {
    let totalIncome: Decimal
    let totalPlanned: Decimal
    let totalSpent: Decimal
    let totalRemaining: Decimal

    /// Percentage of income that has been allocated
    var plannedPercentage: Decimal {
        guard totalIncome > 0 else { return 0 }
        return (totalPlanned / totalIncome) * 100
    }

    /// Percentage of income that has been spent
    var spentPercentage: Decimal {
        guard totalIncome > 0 else { return 0 }
        return (totalSpent / totalIncome) * 100
    }

    /// Percentage of planned budget that has been spent
    var executionPercentage: Decimal {
        guard totalPlanned > 0 else { return 0 }
        return (totalSpent / totalPlanned) * 100
    }

    /// Whether the budget is over-allocated (planned > income)
    var isOverAllocated: Bool {
        totalPlanned > totalIncome
    }

    /// Whether spending has exceeded the plan
    var isOverBudget: Bool {
        totalSpent > totalPlanned
    }
}
