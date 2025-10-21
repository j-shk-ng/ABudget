//
//  BucketType.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation

/// Represents the three main spending buckets for categorizing transactions
enum BucketType: String, Codable, CaseIterable {
    /// Essential expenses required for living
    case needs = "needs"

    /// Discretionary spending and lifestyle expenses
    case wants = "wants"

    /// Money set aside for future goals and emergencies
    case savings = "savings"

    /// Display name for the bucket
    var displayName: String {
        switch self {
        case .needs:
            return "Needs"
        case .wants:
            return "Wants"
        case .savings:
            return "Savings"
        }
    }

    /// Description of the bucket type
    var description: String {
        switch self {
        case .needs:
            return "Essential expenses (housing, food, utilities, transportation)"
        case .wants:
            return "Discretionary spending (entertainment, dining out, hobbies)"
        case .savings:
            return "Future goals (emergency fund, retirement, debt payoff)"
        }
    }

    /// Icon name for the bucket (SF Symbols)
    var iconName: String {
        switch self {
        case .needs:
            return "house.fill"
        case .wants:
            return "heart.fill"
        case .savings:
            return "dollarsign.circle.fill"
        }
    }
}
