//
//  BudgetMethodology.swift
//  ABudget
//
//  Created by Claude on 2025-10-21.
//

import Foundation

/// Represents the different budgeting methodologies supported by ABudget
enum BudgetMethodology: String, Codable, CaseIterable {
    /// Zero-based budgeting: Every dollar is assigned a purpose
    case zeroBased = "zeroBased"

    /// Envelope budgeting: Money is divided into category "envelopes"
    case envelope = "envelope"

    /// Percentage-based budgeting: Income is allocated by percentage rules (e.g., 50/30/20)
    case percentage = "percentage"

    /// Display name for the methodology
    var displayName: String {
        switch self {
        case .zeroBased:
            return "Zero-Based"
        case .envelope:
            return "Envelope"
        case .percentage:
            return "Percentage"
        }
    }

    /// Description of the methodology
    var description: String {
        switch self {
        case .zeroBased:
            return "Every dollar is assigned a purpose, income minus expenses equals zero"
        case .envelope:
            return "Money is divided into category envelopes, spend only what's in each envelope"
        case .percentage:
            return "Income is allocated by percentage rules (e.g., 50% needs, 30% wants, 20% savings)"
        }
    }
}
